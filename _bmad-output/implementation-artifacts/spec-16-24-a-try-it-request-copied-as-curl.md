---
title: 'Story 16.24: A try-it request, copied as curl'
type: 'feature'
created: '2026-09-27'
status: 'done'
baseline_revision: '2086531917a20d727d4db57775dccfc2b242d9d6'
baseline_commit: '2086531917a20d727d4db57775dccfc2b242d9d6'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-16-context.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** The try-it console (Story 16.1) sends a request but gives no way to take it to a terminal, a script or a ticket (owner survey 2026-09-27: IRIS Admin Deck offers every call as curl).

**Approach:** Beside Send, **Copy as curl** builds one POSIX curl command, in the browser, for the request the console's form composes. The command carries the method, the absolute URL with its query, the console's own headers and the body. It is written to the clipboard through the shell's one clipboard routine, and nothing is sent. The tab's access token and every value the record masks read as `<name>` placeholders, and a note beside the control says so. A request the console refuses to send is refused for copy by the same `refuseRequest`, with the same sentence.

## Boundaries & Constraints

**Always:**

- The command is built from the `ComposedRequest` that `composeRequest` answers for the form as it stands, the one Send uses. It is built in the browser and **sends nothing**: no `fetch`, no dialog, no `/api/ocupilot` call. The command never reaches screen context, a tool, the ledger or a log line (AD-57 (4)).
- **Format, one line, one space between arguments:**
  - `curl`;
  - `--globoff` when the URL holds `[`, `]`, `{` or `}`;
  - `--head` for HEAD, or `--request '<METHOD>'` for every other verb;
  - `'<URL>'`;
  - one `--header '<Name>: <value>'` per header, in the order the console sends them: the declared headers the form filled, then any `Content-Type` the console adds, then `Authorization` last;
  - `--data-raw '<body>'` when a body is sent.
- **Quoting.** Every argument that is not one of the option names above is single-quoted, with each `'` inside written `'\''`, so a POSIX shell hands curl each value byte for byte.
- **URL** is `request.url`, the URL the console sends, except that each secret-named path or query value reads `<name>`. With no such value it equals `request.url` exactly.
- **Body** is the body the console sends, byte for byte, with two exceptions:
  - in a JSON-object body, each top-level member the credential pattern names reads `"<Name>"`, and such a body is re-serialized as the record's masking serializes it;
  - in a form body, each secret-named value reads `<name>`.
- **Masked positions are the record's (AD-57 (4)), with `<name>` where the record shows the mask.** `Authorization` is always `Bearer <AccessToken>`, and a declared header of that name is dropped, as Send drops it. Every other header, query parameter, path parameter, form value and top-level JSON member whose name `isSecretName` matches reads as its placeholder. As in the record, nested members and non-JSON bodies are not masked.
- **Refused exactly when Send is**, with the same sentence:
  - the cases are `refuseRequest` answering `own-application` or `admin-write`, the per-operation no-address refusal, and a traversal field;
  - Copy is drawn `aria-disabled="true"`, `aria-describedby` the refusal line (or the traversal error), and a press writes nothing;
  - `curlCommand` asks `refuseRequest` itself, the one function, never a second copy of the rule;
  - a request in flight does not block the copy.
- **Clipboard.** The copy writes through `copyText` (`shell/copy-control.ts`, Story 14.1). The polite status then reads "Copied". When neither route copies, it reads the clipboard sentence (EXPERIENCE.md :269), and the command is shown in a `pre` on the code surface so it can be selected. A form edit or another document clears both.
- **Note.** `tryItCurlNote` is drawn beside the control while the copy is offered, and it describes the control.
- **Strings.** Three new strings: "Copy as curl", "<AccessToken>" and the note. They are folded into EXPERIENCE.md :574 **in place** (993 lines before and after), and appended to `strings.ts` under `/** EXPERIENCE.md:574 */`. "Copied", the clipboard sentence and the four refusals are reused.

**Never:**

- No ObjectScript, route, port, tool, governance key, descriptor or suggested-prompt change. No new dependency, lazy route or `@defer`.
- The copy never carries the access token, the refresh token or a secret-named value. It writes no browser-added header (`Accept`, `User-Agent`, `Origin`, `Sec-Fetch-*`), and it never opens the write confirmation, because nothing is sent.
- `openapi-viewer.page.spec.ts` stays untouched, as in 16.1.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Admin read | `/api/admin`, `GET /v2/web-apps` | `curl --request 'GET' '<origin>/api/admin/v2/web-apps' --header 'Authorization: Bearer <AccessToken>'`; "Copied"; no request | none |
| Write with body | `PUT` on a non-admin app, header `X-A: 1`, body `{"n":"it's"}` | `… --header 'X-A: 1' --header 'Content-Type: application/json' --header 'Authorization: Bearer <AccessToken>' --data-raw '{"n":"it'\''s"}'`; no dialog, nothing sent | none |
| HEAD | any HEAD | `--head` in place of `--request` | none |
| Secrets | query `apiKey`, header `X-Token`, path `{token}`, body `{"Password":"p","Name":"n"}`, form `password` | `apiKey=<apiKey>`, `X-Token: <X-Token>`, `/<token>`, body member `"Password": "<Password>"`, form `password=<password>`; neither the typed values nor the tab's token appear | none |
| No secret in URL | path value `a'b`, query `O'Brien`, unicode, a `/x/../y` literal | URL argument equals `request.url` | none |
| Hostile values | `'`, `''`, `"`, `$HOME`, `$(id)`, a backtick pair, `\`, trailing `\`, LF, CR, TAB, `;&|<>*?~!#`, U+00E9, U+1F600, empty, 100,000 characters (NUL-free) | through `/bin/sh` with a `curl` function, each argument arrives byte for byte, and nothing else runs | none |
| `@` body | body `@/etc/passwd` | `--data-raw` sends it as text, never a file | none |
| Glob characters | base path holding `[` or `{` | `--globoff` precedes the URL | none |
| Refused | `/api/admin` DELETE; `/API/OcuPilot/x`; `..` path value; off-origin `basePath` | Copy `aria-disabled`, described by the same sentence as the refusal line or field error; clipboard untouched | none |
| Clipboard fails | insecure context and `execCommand` false | status reads the clipboard sentence; `pre[data-ocu-try-it="curl"]` holds the command | a form edit clears both |

</intent-contract>

## Code Map

- `ui/src/app/areas/web-applications/try-it.ts`:
  - `ComposedRequest` :59-73;
  - `composeRequest` :258-352: the segment `fill(masked)` :282-293, the query/header/form loop :307-321, `url` via `new URL` :323-331, `displayUrl` :332-333, the body :335-346;
  - `maskBody` :233-247, `refuseRequest` :224, `maskedRecord` :360-366 (its `authorization` filter).
- `ui/src/app/areas/web-applications/try-it.store.ts`:
  - options :45-49; `send` :162-170 is the pattern for `copyCurl`; `reset` :188-194;
  - `setValue`/`setBody` :119-132; the header loop in `dispatch` :211-217; `state()` :247-254.
- `ui/src/app/areas/web-applications/openapi-viewer.page.ts`:
  - the `TryItStore` provider :129-135 (`DOCUMENT` is already injected at :334);
  - the refusal/Send template :273-287, record/answer :288-304;
  - `tryItView` :529-583 (`refused` :533-539, `traversalIndex` :540, `errorId` :551); `onSend` :598-605 is the handler pattern;
  - `@if` conditions stay paren-free member references (client-lint).
- `ui/src/app/shell/copy-control.ts` :65-77 `copyText(doc, text)`: the one clipboard routine (secure-context API, then the selection route); never rejects.
- `ui/src/app/core/secret-names.ts` `isSecretName`; `ui/src/app/core/proposal-view.ts:396` `MASKED_VALUE`.
- `ui/src/app/core/strings.ts`:
  - `:171-175` holds the copy words (`EXPERIENCE.md:269`);
  - `:2950-2973` holds the `tryIt*` keys (`:574`);
  - append after `logHubPrompt3`, before `} as const`.
- EXPERIENCE.md (`_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md`):
  - :574 is the 16.1 console row;
  - :269 is the copy-control row;
  - `ui/tools/strings.test.mjs` :757 pins every citation; values must be unique, and angle brackets balanced.
- `ui/src/styles/_components.scss` :6660-6724 holds the try-it rules; `.ocu-try-it-actions` :6684 has no gap. Append at the file's end (7197 lines). A control inside `[aria-disabled="true"]` is exempt from the DW-1337 contrast check (`browser/structural-walk.mjs:468`).
- Tests to extend or copy from:
  - `ui/src/app/areas/web-applications/openapi-try-it.page.spec.ts`: `mount`, `opened`, `type` and `stubFetch` :60-153;
  - `ui/src/app/shell/code-block.spec.ts` :39-60: the `secureClipboard` and `execCommand` stubs;
  - `ui/browser/openapi-try-it.browser-spec.mjs`: `atDocument` :61, `openConsole` :77, `assertStructure` :105;
  - `ui/browser/copy-out-draft.browser-spec.mjs`: `CLIPBOARD_PERMISSIONS` :54, `overridePermissions` :181, `readText` :210.
- `ui/angular.json:54` `maximumWarning: "2004kB"`: a kB is 1000 B here (`@angular/build` `BYTES_IN_KILOBYTE`), so the headroom is about 1,310 B. `ui/tools/angular-json.test.mjs` :367-381 pins the literal, and `build-output.test.mjs` :168 measures the emitted total against it.

## Tasks & Acceptance

**Execution:**

- `ui/src/app/areas/web-applications/try-it.ts`:
  - extract `sentHeaders(request)` (the declared headers minus any `Authorization`, in order), used by `maskedRecord`, the store's `dispatch` and the builder;
  - `composeRequest` also answers `curlUrl` (built through the same `new URL`, each secret-named path or query value in place as `<name>`, the parser's encoding of each placeholder put back) and `curlBody` (per the Boundaries);
  - add `shellQuote(value)` and `curlCommand(request): {kind:'ok', command} | {kind:'refused', refusal}`, which asks `refuseRequest(request.method, request.url)` first.
- `ui/src/app/areas/web-applications/try-it.store.ts`:
  - add the option `copyText: (text) => Promise<boolean>`;
  - add `copyCurl(key, request)`: build, write, and record `{copied, command}` per console, dropping the outcome if the console was reset meanwhile; it never calls `fetch`;
  - add `copyOutcome(key)`;
  - `setValue`, `setBody` and `reset` clear the outcome;
  - `dispatch` uses `sentHeaders`.
- `ui/src/app/areas/web-applications/openapi-viewer.page.ts`:
  - the provider passes `copyText: (text) => copyText(doc, text)`;
  - the template: the refusal line gains an id and stays; Send is drawn only when there is no refusal; Copy as curl (`ocu-button-text ocu-try-it-copy`, `data-ocu-try-it="copy"`) always follows it in `.ocu-try-it-actions`, with an always-present `role="status"` span (`copy-status`); the note (`curl-note`) is drawn while the copy is offered; `pre.ocu-try-it-code[data-ocu-try-it="curl"]` is drawn on failure;
  - `tryItView` gains `refusalId`, `offersSend`, `copyRefused` (`composition.kind !== 'ok' || refused !== ''`), `copyDescribedBy`, `copyNoteId`, `copyStatus` and `copyFallback`;
  - add `onCopyCurl(view)`, mirroring `onSend`.
- `ui/src/app/core/strings.ts`: append `tryItCopyCurl: 'Copy as curl'`, `tryItCurlAccessToken: '<AccessToken>'` and `tryItCurlNote: 'The command replaces your access token, and each value this console masks in its record of the request, with a name in angle brackets for you to fill in. Check the command for any other secret before you share it.'`, each under `/** EXPERIENCE.md:574 */`, with a one-line comment naming the reused keys.
- EXPERIENCE.md :574 is edited in place. Its first cell gains ` · "Copy as curl" · "<AccessToken>" · "The command replaces your access token, and each value this console masks in its record of the request, with a name in angle brackets for you to fill in. Check the command for any other secret before you share it."`. Its second cell gains, before ` |`: `; and Copy as curl beside Send (Story 16.24, AD-57): one POSIX curl command for the request the form composes, put on the clipboard with nothing sent, `<AccessToken>` standing in for the tab's access token after `Bearer` and each value the record masks reading as its name in angle brackets, which the note beside the control says; it announces as the code block's copy control does (`:269`), shows the command selectable on the code surface when the clipboard fails, and for a request the console refuses is `aria-disabled` and described by the same refusal [AMENDED 2026-09-27 - Story 16.24]`. There is no double-quoted text in that cell, and `wc -l` stays 993.
- `ui/src/styles/_components.scss`: append a Story 16.24 block with `.ocu-try-it-actions { flex-wrap: wrap; align-items: center; gap: var(--ocu-space-2); }` and `.ocu-try-it-copy[aria-disabled='true']` in the Send-disabled idiom (tokens only).
- `ui/tools/try-it-curl.test.mjs` (new): cover every matrix row except the browser-only ones, including:
  - AC3's `/bin/sh` round trip: `execFileSync('/bin/sh', [], {input})`, with the script on stdin (Linux caps one argument at 128 KiB); a `curl()` function printing each argument NUL-terminated; the hostile corpus in each of header, path, query and body;
  - the mask-position parity with `maskedRecord`;
  - the store: `fetch` is never called, the outcome is recorded, a refused copy never calls `copyText`, and an edit or a reset clears the outcome.
- `ui/src/app/areas/web-applications/openapi-try-it.page.spec.ts`: add a `describe` for AC1 (exact written text, "Copied", zero fetches), AC2, AC4 (each refusal, described by the same element or sentence), AC5 and "a write opens no dialog".
- `ui/browser/openapi-try-it.browser-spec.mjs`: extend the header list, and add the following:
  - AC1 on `/api/admin` `GET /v2/web-apps`: Send, then Copy; the clipboard equals the exact command and holds no token; no request other than `/api/ocupilot/refresh` is issued by the press; the command, run by `/bin/sh` with real curl and `<AccessToken>` replaced by the Bearer captured from the Send, answers the JSON the wire carried (curl on PATH is required); `assertStructure` passes with "Copied" shown;
  - in the existing admin-DELETE test: Copy is `aria-disabled` and described by `tryItAdminWrite`; with a sentinel in the clipboard, a press leaves it.
- Only if `npm run build`'s initial total exceeds 2,004,000 B: `ui/angular.json` plus the `ui/tools/angular-json.test.mjs` literal and its comment line, re-based under DW-1166 to 5% above the measured total, rounded up to the next kB. Stop and ask above 3800kB.

**Acceptance Criteria:**

- Given `/api/admin`'s document on the throwaway with the `GET /v2/web-apps` console open, when the person presses Copy as curl, then:
  - the clipboard holds exactly `curl --request 'GET' '<origin>/api/admin/v2/web-apps' --header 'Authorization: Bearer <AccessToken>'`;
  - "Copied" is announced, and no request leaves the page;
  - that command, run by `/bin/sh` with the token filled in, answers the JSON the console showed.
- Given a request carrying a secret-named query value, header, path value and top-level body member, when it is copied, then:
  - each position the record masks reads `<name>`, and the token reads `Bearer <AccessToken>`;
  - the command holds neither the typed secrets nor the tab's token;
  - the control is described by the note.
- Given each hostile value in a header, a path parameter, a query parameter and the body, when the command runs in `/bin/sh` against a `curl` function, then every argument equals the one the console would send, byte for byte, and nothing else runs.
- Given a request the console refuses (admin write, an own application by any spelling, a traversal field, no address), when Copy as curl is pressed, then the control is `aria-disabled`, it is described by the same sentence the console shows, the clipboard is unchanged, and nothing is sent.
- Given a clipboard that refuses both routes, when Copy as curl is pressed, then the clipboard sentence shows with the command selectable on the code surface, and a form edit clears them.
- Given this change, when `npm run test:tools` runs, then the three keys resolve to literals on EXPERIENCE.md :574, the file has 993 lines, and no citation moved.
- Integration (Rule 1): Given the deployed bundle, when `OpenApiViewerPage` handles a Copy as curl press, then it reaches `curlCommand` through `TryItStore.copyCurl`, and the clipboard text of the first AC is its observable effect in a real browser.

### Review Findings

Code review 2026-09-28, full mode, four layers (blind-hunter, edge-case-hunter, verification-gap, acceptance-auditor): 22 findings; 5 patched, 1 ledgered decision-pending, 16 rejected.

- [x] [Review][Defer] The note and AD-57 (5) promise every secret is left out; only names the credential pattern matches are masked (`api_key`, `X-API-Key`, `Cookie` and nested members copy verbatim) [strings.ts:3294] — deferred: DW-1769 `decision-pending` (medium; copy call: reword the note and AD-57 (5), or widen the pattern)
- [x] [Review][Patch] AC1's round trip compared two answers that could both be the same 401: assert the Send answered 200 [browser/openapi-try-it.browser-spec.mjs:258] (medium)
- [x] [Review][Patch] "A request in flight does not block the copy" was unpinned at the page: in-flight case added [openapi-try-it.page.spec.ts:483]
- [x] [Review][Patch] AC5's "a form edit clears them" had no observed mutation: observed, line recorded under Verification
- [x] [Review][Patch] A refused Copy or blocked Send kept the text button's hover and pressed state layer: canceled as on other `aria-disabled` controls [_components.scss:7215]
- [x] [Review][Patch] `curlCommand`'s doc comment said "one line", but a masked JSON body is pretty-printed across lines inside its quotes [try-it.ts:459]

Rejected:

- `low` by-design: a JSON body with a secret member is re-serialized, so numbers beyond double precision, `1e400` and duplicate keys change. The Boundaries specify that re-serialization. AD-57 (5)'s "every other value is written as sent" does not name the exception.
- `low` spec-bound: `--globoff` is written for percent-encoded brackets and braces, beyond the Format bullet. The flag is harmless there, and the matrix's Glob row needs it.
- `low` spec-bound: `.ocu-try-it-actions` is split across two blocks, which `_components.scss`'s append-only footprint forces.
- `low` spec-bound: nothing says how to encode a filled-in placeholder or where to get a token. The copy is fixed, and the token is never shown (AD-28).
- `low` spec-named limits: a body over 128 KiB, and Fetch-forbidden headers written as typed.
- `low`: duplicate declared header names copy both, while Send keeps the last. Only an operation declaring one name twice triggers it; `MgmntPort` merges by name and location.
- `low`: an empty secret-named path value reads `<name>`. The record masks that position too, and the parity test holds the two equal.
- `low`: an empty status span adds a second gap. Hiding an empty live region would stop its announcement.
- `low`: the fallback `pre` has no heading. It follows the status sentence, the record and answer `pre`s carry no accessible name either, and the component case pins it.
- `low`: a parameter named `AccessToken` shares the token's placeholder, and a spaces-only header is dropped by curl but sent empty by fetch.
- `low`: one console keeps "Copied" after another console copies, as the code block's control does.
- `low` theoretical: a base path holding a tab or line break around marker text, and a `//host:{secret}` document path, break `curlHref`.
- `false`: the reused-keys comment in `strings.ts` spans two lines. It is one comment wrapped at the file's width.

## Spec Change Log

- 2026-09-28T06:00Z, lead spec gate: the masking decision is accepted as planned (the copy masks everything the request record masks, AD-57 item 4; safer than AC2's minimum and consistent with AD-59's `<Name>` convention). AD-57's Binds and item 5 are written into the spine by the lead in this gate's commit; the implement stage does not write them. `ui/angular.json` (and `ui/tools/angular-json.test.mjs`, in footprint) may change only for a DW-1166 re-base; the lead reports `ui/angular.json` as a footprint extension if touched.

## Review Triage Log

### 2026-09-28 — Review pass

- verdicts: 15 findings — high 0, medium 1, low 7, false 7, maybe-false 0
- findings:
  - `[medium]` `[patch]` verification-gap: `curlUrl` was never checked for non-secret path or query values that need encoding beside a secret — added the "beside a secret" node case (`a/b?c` in the path, `x&y=1#z` in the query); its mutation reddens it.
  - `[low]` `[patch]` verification-gap: a second press's re-announcement (status emptied before the clipboard answers) was unpinned — added the "a second press" store case; its mutation reddens it.
  - `[false]` `[reject]` verification-gap: `curlUrl === request.url` with no secret cannot fail — a mutation building `curlUrl` from the unresolved text reddens it (`/x/../y` and `O'Brien` survive there: probe printed `.../api/x/x/../y/a'b?q=O'Brien` against `.../api/x/y/a'b?q=O%27Brien`).
  - `[low]` `[patch]` verification-gap: AC2's only mutation replaced the token; none covered the `<name>` placeholders — applied "a secret-named header copied as typed", red in node and page; line recorded under Verification.
  - `[false]` `[reject]` intent-alignment D1: "no `/api/ocupilot` call" is not asserted literally — `TryItStore` holds no `ApiService`, `copyCurl` calls only `curlCommand` and `copyText`, and the refresh exemption is the spec's own browser task.
  - `[low]` `[reject]` intent-alignment D2: `--globoff` is written for an encoded bracket from a typed value — the flag changes nothing curl sends; narrowing it needs the base path on the request, a new field for a cosmetic flag.
  - `[low]` `[reject]` intent-alignment D3: argument parity is checked against `fetch`'s init, not the wire; a Latin-1 non-ASCII header value would differ on the wire (inference) — rare, AC3 pins argument parity, and a fix needs an encoding branch.
  - `[false]` `[reject]` intent-alignment D4: the never-reaches-context rule has no test — `core/screen-context.ts` reads no DOM and `TryItStore` is used only by `OpenApiViewerPage`.
  - `[false]` `[reject]` intent-alignment D5: "another document clears it" is checked only at `store.reset()` — `loadFromRoute` (`openapi-viewer.page.ts:438`) calls `tryIt.reset()`, which clears the consoles map that holds the outcome.
  - `[false]` `[reject]` intent-alignment D6: the PUT-with-body row is pinned only in node — the page's AC2 case copies a POST with a body and asserts its members, and the exact format is `curlCommand`'s, which the page calls.
  - `[low]` `[reject]` intent-alignment D7a: re-serializing a JSON body with a secret member can reorder integer-like keys and round numbers above 2^53 — specified behavior ("re-serialized as the record's masking serializes it"); changing it edits the spec.
  - `[low]` `[reject]` intent-alignment D7b: `Authorization` is written even when the tab holds no token — specified ("`Authorization` is always `Bearer <AccessToken>`"); changing it edits the spec.
  - `[low]` `[reject]` intent-alignment D8: a formData operation on GET or HEAD copies a body curl refuses with `--head` — needs a document declaring form parameters on a read, Send fails the same request, and a fix adds a branch.
  - `[false]` `[reject]` intent-alignment D9: the parity test compares positions, not names — names are pinned by the node secrets case and the page's AC2 case.
  - `[false]` `[reject]` intent-alignment D10: `ui/angular.json` changes outside the contract — the spec's last task and Change Log sanction the re-base, and the build measured 2,006,491 B.

## Design Notes

**Decision, flagged for the spec gate: what is masked.** AC2 names "the session's access token, or any header the console masks". The record also masks secret-named query, path, form and top-level body values (AD-57 (4)). The spec masks all of them. The reasons:

- a command meant for "a ticket" must not carry a typed password;
- the one existing copy-a-command surface puts `<Name>` at every name the credential pattern matches (AD-59);
- Conventions › Secrets keeps secrets write-only.

The other reading would copy body and query secrets verbatim. That reading is one line in `curlCommand` and a matrix row. The spine change below binds the choice.

**Format choices.**

- `--data-raw` rather than `--data-binary`, because the latter reads a leading `@` as a file.
- `--head`, because `--request 'HEAD'` makes curl wait for a body.
- `--globoff`, because curl would expand `[]{}`.
- One line, because a trailing space after a line-continuation backslash breaks a pasted command.
- Long option names, which read clearly in a ticket.
- The refused control is `aria-disabled`, not hidden, so that "asks to copy" is possible and the reason is announced (the gated-control rule).

**Named limits** (each `wontfix-theoretical` unless made real):

- A raw U+0000 cannot travel in a POSIX argument. It can reach only a typed body, where it is invalid JSON.
- A body above Linux's 128 KiB per-argument limit fails at exec there (inference).
- A header value holding a line break, or a header the Fetch standard forbids a page to set (`Cookie`, `Host`, `Sec-*`), is written as typed. The console itself cannot send the first, and the browser drops the second (inference).
- `--data-raw` needs curl 7.43.0 or later (inference).

**Spine change for the lead (Rule 20).** It does not contradict AD-57's Rule. Add `Story 16.24` to AD-57's Binds, and append:

> 5. **Copy as curl** [AMENDED 2026-09-27, Story 16.24 spec gate, Rule 20]. The console may put the request its form composes on the clipboard as one POSIX curl command, built in the browser and sending nothing. It is refused whenever Send is, by the same function and with the same reason (item 2). It masks what the record masks (item 4): the tab's access token reads `Bearer <AccessToken>`, and each header, query or path parameter, form value or top-level body member the Conventions › Secrets pattern names reads `<name>`, so no secret value reaches the clipboard. Every other value is written as sent, each argument single-quoted for a POSIX shell. The command never reaches the model, a tool result, screen context, the ledger or a log line.

**Governing ADs:**

- AD-57 (items 1, 2 and 4, with the proposed item 5); AD-10's pointer to AD-57;
- AD-11 rule 4 and AD-47 (the copy issues no request, and evaluates nothing);
- AD-19 (the outcome lives in the store), AD-20 (no API call), AD-28 (the token is never copied);
- AD-24 and AD-36 (context unchanged), AD-39 (the reasons are reused), AD-1 and AD-22 (no tool, no key), AD-5 (no descriptor change; the viewer keeps its prompts);
- Conventions › Secrets, › Client asset homes and Rule 14.
- AD-59 binds write tools' drafts, not this surface. Its `<Name>` convention is followed.

**Integration.**

- **Consumes:**
  - 16.1's `composeRequest`, `refuseRequest`, `maskedRecord` and `TryItStore`;
  - 14.1's `copyText`;
  - `isSecretName`.
- **Consumed-by:** `OpenApiViewerPage` in this story. No later story is planned.

**Bundle.** The headroom is about 1,310 B, so crossing the warning is likely. If it is crossed, the warning is re-based under DW-1166 (last task).

**Footprint.**

- All paths are Epic 16's, except `ui/angular.json`, which is uncontended; report it under `footprint_extensions` if it is touched.
- Existing-line edits: `try-it.ts`, `try-it.store.ts`, the page, EXPERIENCE.md :574, and the `angular-json.test.mjs` literal (only on a re-base).
- `strings.ts` and `_components.scss` are append-only.

**Ledger.** The inbox is empty. There is no ObjectScript change, because the story is browser-only by AD-57.

## Verification

**Commands** (from `ui/`; browser runs export `OCUPILOT_BROWSER_ORIGIN=http://localhost:52776 OCUPILOT_BROWSER_CONTAINER=ocupilot-ci`):

- (loop) `node --test tools/try-it-curl.test.mjs tools/try-it.test.mjs tools/credential-lists.test.mjs tools/strings.test.mjs` -- expected: green.
- (loop) `npx ng test --include src/app/areas/web-applications/openapi-try-it.page.spec.ts` -- expected: green.
- (loop) `npm run build` -- expected: every prebuild checker passes. Report the initial total, and re-base per the last task if it is over 2004kB.
- (loop) `docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/`, then `node --test --test-concurrency=1 browser/openapi-try-it.browser-spec.mjs browser/a11y-structural-invariants.browser-spec.mjs` -- expected: green in both themes with no new baseline key.
- (loop) `bash scripts/lint-docs.sh` and `wc -l` on EXPERIENCE.md -- expected: clean, and 993.
- (once, before dev_complete) `npm test` -- expected: green, with the bundle at or under `maximumWarning`.
- There is no ObjectScript sweep, because no ObjectScript changes. The full browser suite runs in CI.

**Mutations to record** (Rule 19, one per AC, observed red and reverted byte-identical):

- `copyCurl` calls `dispatch` → the store's "sends nothing" test.
- The real token goes into the copied `Authorization` → the page AC2 case and browser AC1.
- Double quotes replace single quotes → the `/bin/sh` corpus.
- `refuseRequest` is dropped from `curlCommand` → the node refusal case. Copy is drawn without `aria-disabled` → the component AC4 case.
- `copyFallback` is left empty → the component clipboard-failure case.
- `tryItCurlNote` is reworded → `strings.test.mjs`.
- `onCopyCurl` is unbound, then the bundle rebuilt and redeployed → browser AC1.

**Observed** (implement, 2026-09-28; each applied, seen red, reverted, `git status --short` and `git diff --stat` unchanged):

- mutation: `copyCurl` calls `dispatch` -> "the store copies and never sends" red.
- mutation: the tab's token replaces `<AccessToken>` in what `copyCurl` writes -> the page's AC1, AC2 and write cases red; rebuilt and redeployed, browser AC1 red on "the clipboard holds no token".
- mutation: `shellQuote` writes double quotes -> the `/bin/sh` corpus red with eight others; with `"` and `\` escaped the corpus still reds while the parity case passes.
- mutation: `refuseRequest` dropped from `curlCommand` -> "a request the console refuses is refused for copy" and the store's refused-copy case red.
- mutation: Copy drawn without `aria-disabled` -> the page's refusals case red.
- mutation: `copyFallback` left empty -> the page's clipboard-failure case red.
- mutation: `tryItCurlNote` reworded -> `strings.test.mjs`'s citation, completeness and authorization cases red.
- mutation: `onCopyCurl` unbound, rebuilt and redeployed -> browser AC1 red (the wait for "Copied" times out).
- mutation (review): a secret-named header copied as typed -> the node secrets and parity cases and the page's AC2 case red.
- mutation (review): non-secret path and query values beside a secret pushed unencoded into `curlUrl` -> "beside a secret, every other path and query value is encoded exactly as request.url encodes it" red.
- mutation (review): `copyCurl` no longer empties the outcome and notifies before the clipboard answers -> "a second press empties the status before the clipboard answers" red.
- mutation (code review): `setValue` no longer clears the copy outcome -> the page's clipboard-failure case red ("an edit clears both").
- mutation (code review): `copyRefused` also true while a request is in flight -> the page's new in-flight case red, alone.
- mutation (code review): browser AC1 fills `<AccessToken>` with a wrong value -> the round trip red (bundle rebuilt and redeployed first; 6/6 green before).
- Initial total 2,006,491 B, over 2,004,000 B; `maximumWarning` re-based to 2107kB under DW-1166.

## Auto Run Result

Implement pass, 2026-09-28 (baseline `2086531917a20d727d4db57775dccfc2b242d9d6`).

**Change.** Copy as curl follows Send in every try-it console. `curlCommand` (`try-it.ts`) builds one POSIX line from the `ComposedRequest` Send uses, which now also answers `curlUrl` and `curlBody`; it asks `refuseRequest` first. `TryItStore.copyCurl` writes it through the injected `copyText` and records `{copied, command}` per console; an edit, a body edit or `reset` clears it, and nothing is sent. The page draws Copy `aria-disabled` and described by the refusal or traversal error when refused, and by the note otherwise, with a `role="status"` line and a `pre` fallback.

**Files.**

- `ui/src/app/areas/web-applications/try-it.ts`: `sentHeaders`, `shellQuote`, `curlCommand`; `curlUrl`/`curlBody` on the composed request.
- `ui/src/app/areas/web-applications/try-it.store.ts`: the `copyText` option, `copyCurl`, `copyOutcome`; `dispatch` uses `sentHeaders`.
- `ui/src/app/areas/web-applications/openapi-viewer.page.ts`: the provider's `copyText`, the control, status, note and fallback, `onCopyCurl`.
- `ui/src/app/core/strings.ts`, EXPERIENCE.md :574 (993 lines), `ui/src/styles/_components.scss`: the three strings, the row, the actions row and the refused idiom.
- `ui/tools/try-it-curl.test.mjs` (new), `openapi-try-it.page.spec.ts`, `ui/browser/openapi-try-it.browser-spec.mjs`: the tests.
- `ui/angular.json`, `ui/tools/angular-json.test.mjs`: the DW-1166 re-base (footprint extension for `ui/angular.json`).

**Verification fix.** The Matrix Test Audit found the glob row unmet: the parser encodes a base path's `{` as `%7B`, so no `--globoff` was written. `curlCommand` now writes `--globoff` for a bracket or brace raw or percent-encoded, and the test pins the row.

**Review.** Two layers (verification-gap, intent-alignment); 15 findings: 3 patched (1 medium, 2 low, all test coverage or mutation lines, applied by the stage), 5 low rejected, 7 false, none deferred. Follow-up review: not recommended (one medium patched, no high).

**Verified** (from `ui/`, slot A, `ocupilot-ci`): the loop node files 86/86; the page spec 20/20; `npm run build` with every prebuild checker clean, initial total **2,006,491 B**, so `maximumWarning` re-based 2004kB -> **2107kB** (5% above, under the 3800kB stop); bundle redeployed, then `openapi-try-it.browser-spec.mjs` 6/6 (real curl run by `/bin/sh` answers the Send's JSON) and `a11y-structural-invariants.browser-spec.mjs` 12/12 (both themes, no new baseline key); `lint-docs.sh` clean; EXPERIENCE.md 993 lines; `npm test` 1666 node + 1622 component green. Every recorded mutation reddened and was reverted byte-identical. No ObjectScript changed, so no sweep.

**Residual risk.** The new node test and the browser AC1 test need `curl` on PATH; the CI jobs run on `ubuntu-24.04`, where `ci.yml` already calls `curl`.

Status: done
Blocking condition: none

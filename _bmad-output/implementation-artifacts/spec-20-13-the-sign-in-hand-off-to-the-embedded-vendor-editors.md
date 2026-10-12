---
title: 'Story 20.13: The sign-in hand-off to the embedded vendor editors'
type: 'feature'
created: '2026-10-12'
status: 'done'
baseline_revision: '6e02c22f6d768b0ca9e3eb6a02bad1448c746162'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md'
warnings: [oversized]
deferred:
  - summary: >-
      The Angular component app-interop-editor-frame first runs in a real browser in Story 20.7, so its host-filling style and its Renderer2 src set are observed by no browser test until then.
    evidence: |-
      interop-editor-frame.spec.ts runs in jsdom, which computes no layout, and the browser spec mounts a harness iframe built from the shipped interopEditorSource, not the component. The intent excludes any screen or route here, so the component has no real-browser host before Story 20.7, whose browser spec re-runs interop-editor-spec.mjs against its real screens.
    location: >-
      ui/src/app/areas/interoperability/interop-editor-frame.ts:52
    severity: low
---

<intent-contract>

## Intent

**Problem:** Stories 20.7, 20.8 and 20.10 embed the vendor's `/ui/interop` editors in place, and none of them can start until there is a way to load an editor inside the shell that is already signed in. That way must not hand the editor a password or a token, must not use the editors' message-driven sign-in, and must not loosen the origin's posture (DW-2141, decided as option A and written as AD-63).

**Approach:** Build the AD-63 frame. A framework-free builder makes the frame's only source: `/ui/interop/<editor>/index.html` on the instance's origin, carrying only the editor's own namespace and document parameters from a closed vocabulary, with values of checked shape. An `app-interop-editor-frame` component draws that source in one unsandboxed `<iframe>` and reaches nothing inside it. The editor signs itself in from the browser-level login, and OcuPilot's existing sign-out ends that sign-in (measured at this plan). Static guards and a browser spec against the real editors on `ocupilot-b-ci` pin every limit.

## Boundaries & Constraints

**Always:**

- **AD-63's five limits, verbatim:**
  1. Fixed source.
  2. Normal mode only.
  3. OcuPilot reaches nothing in the frame.
  4. Sign-out ends the editors' sign-in.
  5. No sandbox.
- **The source** is built only by `interopEditorSource(editor, namespace, document)` in `ui/src/app/core/vendor-frame.ts`. It takes:
  - `editor` from the closed vocabulary below;
  - `namespace` as the screen's own read answered it, drawn only while it equals `ScopeService.namespace()` (the namespaces read);
  - `document` from the consumer's read, of class-name shape.

  Each value is percent-encoded. Anything else answers `null`, and then no frame is drawn and nothing is requested.
- **Vocabulary.** Each editor's document parameter was read in its bundle and measured at this plan:

  | Editor | Document parameter |
  |---|---|
  | `rule-editor` | `rule` |
  | `dtl-editor` | `DTL` |
  | `bpl-editor` | `BP` |

  All three read the namespace from `$NAMESPACE`, spelled literally as the vendor's own links spell it.
- **Setting the source.** `src` is set with `Renderer2`, never through a binding or a sanitizer bypass, as the class reference's frame does (`document-viewer.page.ts`:539-540).
- **Strings.** The frame's title is its accessible name, one per editor, held in `strings.ts` and EXPERIENCE.md's Fixed strings.
- **Contended files take add-only edits** (Design Notes › Contended files).

**Never:**

- `VSCODE`, `READONLY`, or any other parameter in the source. No source from another origin, or from a path or value built from a person's text.
- A `sandbox`, `allow`, `srcdoc` or `credentialless` attribute on the frame.
- Any OcuPilot code that does any of these:
  - reads `contentWindow`, `contentDocument` or `frames`;
  - posts a message;
  - listens for a frame's messages;
  - reads or writes a vendor storage key, or `vscodeMode`.
- A change to the token store, `Session` sign-in or sign-out, the shell's content-security policy (`StaticHandler.ContentSecurityPolicy`), `index.html` or its nonce, or any response header. CORS stays off.
- In this story: no screen, descriptor, rail entry, route, entity type, tool, governance key, ObjectScript class or `%Api.InteropEditors` call (AD-62 (1)). Story 20.7 builds the editor screens.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Editor, empty | `rule-editor`, `HSCUSTOM` (the namespace on screen), no document | source `/ui/interop/rule-editor/index.html?$NAMESPACE=HSCUSTOM`. The editor's `POST /api/interop-editors/login` has no body and answers 200, and the editor renders signed in as the person | — |
| Editor, document | an editor with a class name (`dtl-editor` + `<class>`) | `…?$NAMESPACE=HSCUSTOM&DTL=<class>` (`&BP=`, and `&rule=` for a rule). The editor requests that document's read, `/api/interop-editors/v7/HSCUSTOM/{dtl\|bpl\|rules}/<class>`. Measured: present DTL and BPL classes opened (200); absent names answered 404 | — |
| Refused source | an editor outside the vocabulary; a namespace that is empty or outside its shape; a non-empty document outside its shape (`..`, `/`, `&`, `#`, `?`, `=`, a space); or a namespace other than the one on screen | `null`. No frame is drawn, nothing is requested | — |
| Namespace switch | the scope moves to another namespace | the frame is drawn only once the consumer's namespace matches the new one. The old document unloads, and the vendor clears its own keys on `pagehide` (measured) | — |
| Sign-out | a signed-in editor frame, then Sign out from the account menu | the shell withholds every screen, so the frame goes. No `_Editor-` key is left in the tab. The empty-body editors login, the editor's held access token and its held refresh token each answer 401 | — |
| Login ended elsewhere | the editor's own Logout, or another sign-out of this browser | OcuPilot's pair is refused (measured), so its next request shows the session-ended card and withholds the frame. Until then the editor may show its own sign-in form, which OcuPilot never fills or reads. This is a named consequence, measured at this plan; it changes no code and has no test in this story | — |

</intent-contract>

## Code Map

### Client: what this story adds and edits

- **`ui/src/app/areas/system-explorer/document-viewer.store.ts`** is the sibling builder.
  - `CLASS_NAME` :37 and `NAMESPACE_NAME` :40 are file-private shapes. They move to `core/vendor-frame.ts` and are imported back.
  - `classReferenceUrl` :53-57 stays where it is.
  - Its encoding and null cases are pinned at `document-viewer.page.spec.ts`:482-495.
- **`document-viewer.page.ts`** is the sibling frame.
  - Design comment :96-108; template :197-204 (`sandbox=""`, `data-ocu-source`, `[attr.title]`).
  - `referenceSource` :405-412 draws only for the namespace on screen.
  - `syncReference` and `loadReference` :513-540 set `src` with `Renderer2`. Its spec pins the attributes at :346-357.
- **`ui/src/app/core/scope.ts`**: `ScopeService` :152, `namespace()` :214. The value is chosen from the namespaces read, never a caller string.
- **Token storage.** `ui/src/app/core/token-store.ts`: `PAIR_STORAGE_KEY` `ocupilot.token-pair` :64, the only code use of `sessionStorage` :88, `clear()` :194-197. `turn.ts`:104 holds `ocupilot.conversation`.
- **Sign-out.** `ui/src/app/core/session.ts` `signOut()` :684-712 posts `/logout` with the Bearer and `credentials: 'include'` :703-707.
- **The shell gate.** `ui/src/app/app.ts`:233 renders the whole shell, `<router-outlet>` included, only while signed in. Every frame therefore goes on sign-out and on session end. Nothing changes here.
- **Content-security policy.** The shell sends `default-src 'self'` with no `frame-src`, so a same-origin frame is admitted; `frame-ancestors 'none'` applies to the shell only.
  - Set by `src/OcuPilot/Api/StaticHandler.cls` `ContentSecurityPolicy` :348-351.
  - Pinned exactly at `src/OcuPilot/Test/Static.cls`:176-177.
  - Unchanged by this story.
- **`ui/tools/api.test.mjs`** holds the credential-channel bans.
  - `FORBIDDEN` :704-713: cookie, `localStorage`, `BroadcastChannel`, the storage listener, `.postMessage(`. It scans all of `ui/src` with comments blanked :740-753.
  - Two fixture tests list the caught lines: the hostile list `caught` `[1..5]` :755-777, and the scan fixture `hits` `[3..7]` :779-797.
  - `isOcuPilotApiPath('/ui/interop/index.html') === false` :139.
- **Strings.** `ui/src/app/core/strings.ts` gains three keys. `ui/tools/strings.test.mjs` derives the key count and bounds it at 3400 (:611). EXPERIENCE.md:604 is the last Fixed-strings row: append to it and insert no line, because `/** EXPERIENCE.md:n */` references are checked. EXPERIENCE.md:81 (the Sign out row) already says sign-out ends the embedded editors' login.

### Browser harness

- `ui/browser/panel-spec.mjs` `signedInAt` :62-83; `namespace-features.mjs` `waitForMapAnswered` :62-64.
- `account-and-filter.browser-spec.mjs`:130-170 opens the account menu and clicks Sign out (the last `menuitem`).
- `system-explorer-documatic.browser-spec.mjs`:127-182 is the frame sibling: requests recorded with `page.on('request')`, the frame through `contentFrame()`.
- Browser specs import core TypeScript directly (`structural-walk.mjs`:50), so the spec builds its frame's source with the shipped builder.
- A new spec without a timing is weighed at the median (`ci-shards.mjs`:92).

### Vendor (read only)

- **Bundles:** `irisui/ui/interop/{rule,dtl,bpl}-editor/main.*.js`.
  - Normal mode always sends `POST /api/interop-editors/login` with a `null` body. When that fails, it falls back to its own username and password form.
  - `?VSCODE=1` skips that login, sets `localStorage.vscodeMode` and installs `window.onmessage` for `{type:"auth", …}`. Every `window.parent.postMessage(…, "*")` is gated on `vscodeMode`.
  - Token keys are `<App>-<n>-{user,accessToken,refreshToken}` in sessionStorage (`Rule_Editor`, `DTL_Editor`, `BPL_Editor`). They are cleared on `pagehide`.
  - There is no `window.top` read and no top navigation.
  - Self-navigation: the logo goes to `UtilHome.csp`, and DTL/BPL's "Back to standard UI" goes to the Zen editor. Help, "Open in Zen" and the cross-editor open buttons use `window.open(…, "_blank")`.
- **Web applications:** `/ui/interop` is static and unauthenticated (`irisui/README.md`). `/api/interop-editors` is `%Api.InteropEditors` (v7).

## Tasks & Acceptance

**Execution:**

- [ ] **DW-2141 (the whole story).** Implement AD-63's option A as below. The four ACs are the evidence for the entry's `resolved-by` at adjudication.
- [ ] `ui/src/app/core/strings.ts` (add-only): `interopRuleEditorTitle` "Rule editor", `interopDtlEditorTitle` "DTL editor", `interopBplEditorTitle` "BPL editor".
- [ ] EXPERIENCE.md:604 (append, no new line): the three literals, with a Story 20.13 clause: the embedded vendor editors' frame titles, each the frame's accessible name. Then run `cd ui && npm run test:tools`.
- [ ] `ui/src/app/core/vendor-frame.ts` (new, framework-free: imports no `@angular/*`).
  - **Moved shapes.** `CLASS_NAME` and `NAMESPACE_NAME`, moved from `document-viewer.store.ts` and exported.
  - **`INTEROP_EDITORS`.** The closed vocabulary `rule-editor`→`rule`, `dtl-editor`→`DTL`, `bpl-editor`→`BP`, each with its title's `STRINGS` key, as a readonly record typed `InteropEditor`.
  - **`interopEditorSource(editor, namespace, document = '')`**, as Boundaries say:
    - It answers `/ui/interop/<editor>/index.html?$NAMESPACE=<enc(ns)>`, plus `&<param>=<enc(doc)>` when a document is given.
    - It strips no extension and adds nothing else.
    - It answers `null` for an unknown editor, a namespace failing `NAMESPACE_NAME`, or a non-empty document failing `CLASS_NAME`.
- [ ] `ui/src/app/areas/system-explorer/document-viewer.store.ts`: import the two shapes from `core/vendor-frame.ts` and delete its own copies. Its behavior and specs are unchanged.
- [ ] `ui/src/app/areas/interoperability/interop-editor-frame.ts` (new standalone component `app-interop-editor-frame`, `OnPush`, signal inputs).
  - **Inputs.** `editor` (required, `InteropEditor`), `namespace` (required: the namespace the consumer's read answered in) and `document` (default `''`).
  - **Drawing.** It draws `<iframe class="ocu-interop-editor-frame" data-ocu-source="interop-editor-frame" [attr.title]>` only while `namespace === scope.namespace()` and `interopEditorSource` answers non-null. Otherwise it draws nothing.
  - **Setting `src`.** It sets `src` with `Renderer2` in an `afterRenderEffect` whenever the source changes, as `syncReference` does.
  - **No attributes beyond those.** No sandbox, no `allow`, no listener on the frame, and no storage access.
  - **Style.** The frame fills its host (block, full width and height, no border); no color literal.
  - **Header.** The doc comment states AD-63's limits and the named consequence in contract form.
- [ ] `ui/tools/api.test.mjs` (extend `FORBIDDEN` and both fixture tests):
  - `/\bcontent(Window|Document)\b/` and `/\bwindow\s*\.\s*frames\b/`: OcuPilot reaches nothing in a frame (AD-63 (3)).
  - `/\bVSCODE\b/`: normal mode only (AD-63 (2)).
  - `/_Editor-|\bvscodeMode\b/`: no vendor editor storage key, so no token is ever pre-written (AD-63 (2)).
  - Each gets a hostile fixture line and a scan fixture line, and the `caught` and `hits` arrays grow to match.
- [ ] `ui/tools/vendor-frame.test.mjs` (new; imports `core/vendor-frame.ts` as `api.test.mjs` imports core):
  - the exact source for each editor, with and without a document;
  - percent-encoding of a `%`-led namespace (`%SYS`);
  - `null` for each refused shape in the matrix, including `X&VSCODE=1`, `X#y`, `../x` and an unknown editor;
  - no answer ever contains `VSCODE` or `READONLY`;
  - the moved shapes still accept what `classReferenceUrl` accepted;
  - a scan of non-spec `ui/src` code (comments blanked, as in `api.test.mjs`) finds the literal `/ui/interop` only in `core/vendor-frame.ts`, so the builder is the frame's one source.
- [ ] `ui/src/app/areas/interoperability/interop-editor-frame.spec.ts` (new, sibling of `document-viewer.page.spec.ts`:346-357), with a `ScopeService` double:
  - one frame;
  - `src` equals the builder's answer;
  - `hasAttribute` is false for `sandbox`, `allow`, `srcdoc` and `credentialless`;
  - the title is each editor's string;
  - no frame for a refused source, or while the namespace differs from the scope's;
  - a namespace or document change re-sets `src`;
  - `sessionStorage` holds the same keys before and after rendering.
- [ ] `ui/browser/interop-editor-spec.mjs` (new helper module, for this story and Stories 20.7, 20.8 and 20.10):
  - **`watchEditorTraffic(page)`** records method, path, query, post body and status for `/ui/interop/` and `/api/interop-editors/`.
  - **`armMessageCounters(page)`** uses `evaluateOnNewDocument` to count `message` events in every window.
  - **`assertSignedInSilently(...)`** asserts AC1's and AC2's runtime clauses.
  - **`assertSignOutEndsEditors(page, held)`** asserts AC3.
- [ ] `ui/browser/interop-editor-frame.browser-spec.mjs` (new). `before` refuses `LIVE_CONTAINER` and requires readiness `installed`. Each test signs in through `signedInAt` at `/ocupilot/?ns=HSCUSTOM`, waits for `waitForMapAnswered`, then mounts a frame inside `app-screen-outlet`, built with `interopEditorSource` and no other attribute but its title (the harness, Design Notes). Tests:
  1. Each of the three editors signs itself in (AC1, AC2's runtime half), one subtest per editor. Before mounting, the tab's sessionStorage keys all start `ocupilot.`. Each frame carries a document the test names and never creates (`OcuPilotProbe.EditorFrame<Editor>`), so the document read it requests is asserted without depending on a class the test did not make.
  2. With a DTL frame signed in, the spec holds the editor's tokens, then signs out through the account menu (AC3).

**Acceptance Criteria:**

- **AC1 (silent sign-in, no password, normal mode; integration with the real editors).** Given the signed-in shell on `ocupilot-b-ci` and each of the three editors framed from `interopEditorSource` in the routed screen's host, when it loads, then:
  - its `POST /api/interop-editors/login` carries no body and answers 200, and it renders signed in as the person;
  - it requests the read of the document its own parameter names (`/v7/HSCUSTOM/{rules|dtl|bpl}/<name>`);
  - no request it makes (its document or any API call) carries a password, either OcuPilot token (in the URL, the body or `Authorization`) or `VSCODE`;
  - neither the frame nor the shell receives a message;
  - `localStorage.vscodeMode` is unset, and the frame holds no password field.
- **AC2 (nothing pre-written or read, origin unchanged).** Given the same frames, when an editor has signed in, then:
  - before it loaded, every sessionStorage key began `ocupilot.`;
  - its access token is neither OcuPilot token;
  - OcuPilot's pair is byte-identical;
  - localStorage holds neither token;
  - the shell's policy still equals `Test/Static.cls`'s exact string;
  - `api.test.mjs` finds no frame read, message, `VSCODE`, vendor storage key or cross-tab channel under `ui/src`.
- **AC3 (sign-out ends the editors' sign-in).** Given a DTL frame signed in and its held access and refresh tokens, when the person chooses Sign out in the account menu, then:
  - no `iframe` remains in the document;
  - no `_Editor-` key remains in sessionStorage;
  - the empty-body `POST /api/interop-editors/login`, a v7 call under the held access token, and `POST /api/interop-editors/refresh` with the held refresh token each answer 401.
- **AC4 (the source contract).** Given `interopEditorSource` and `app-interop-editor-frame`, when given an editor, a namespace and a document:
  - the source is exactly the matrix's address, or `null` for every refused input;
  - the component draws one frame with that `src` and its title, carrying no `sandbox`, `allow`, `srcdoc` or `credentialless`, and only while the namespace is the one on screen;
  - it writes nothing to sessionStorage.

## Spec Change Log

- 2026-10-12, spec gate (lead): AD-63 amendments written (builder, sign-out re-measured, editor Logout); the opened-tab sentence waits on Q1.

## Review Triage Log

### 2026-10-12 - Review pass

- verdicts: 15 findings - high 0, medium 2, low 11, false 2, maybe-false 0
- findings:
  - `[medium]` `[patch]` verification-gap: AD-63 limit 3's "hears no message, puts no listener on the frame" was pinned by nothing - no `FORBIDDEN` rule matched a message listener and the attribute test is blind to listeners (a `(load)` binding or a `window:message` host listener passed every gate). Patched: `api.test.mjs` bans `addEventListener('message')`, `window:message` and `onmessage` with a hostile and a scan fixture line each; `interop-editor-frame.spec.ts` gains a listener-spy test with positive controls for a frame and a window listener; both mutations (`(load)`, `@HostListener('window:message')`) observed red and reverted.
  - `[low]` `[patch]` verification-gap: AC3's access-token and refresh-token 401 clauses and "no frame remains" were never reached by the recorded mutation, which failed at the first clause. Patched: `assertSignOutEndsEditors` reads all three statuses and asserts them together; the `credentials: 'omit'` mutation now shows login, access and refresh each answering 200, and mounting the harness frame outside the outlet reddens "no frame remains"; both reverted.
  - `[low]` `[patch]` verification-gap: AC1/AC2 sub-clauses have no mutation line of their own. Rule 19 asks one mutation per AC (AC1 and AC2 each have one or more recorded), so the sub-clauses stand; the one assertion that could be vacuous, the content-security-policy watcher with no positive control, is patched with a `fetch` the policy refuses, which the watcher is shown to report.
  - `[low]` `[defer]` verification-gap: the component's host-filling style and `Renderer2` src set are observed by no browser test; the intent excludes any screen or route, so the first real-browser host is Story 20.7 (frontmatter `deferred:`).
  - `[low]` `[reject]` verification-gap (other): `after.pair === before.pair` can meet a renewal if a test outlasts about 50 s - each editor test finishes in about 2.5 s and a failure names the clause; not worth a guard.
  - `[low]` `[reject]` verification-gap (other): the document read's status is not asserted - AC1 asks that the editor requests the read, and the login (200) and the rendered user name already show the sign-in worked.
  - `[low]` `[reject]` verification-gap (other): the policy comparison parses `Test/Static.cls` text - AC2 names that string as the comparand, and a reformatted line fails loudly on the pinned-policy match.
  - `[low]` `[reject]` verification-gap (other): the moved-shapes check is a source-text check - the shapes' behavior stays pinned by the existing `classReferenceUrl` cases, and the text check is what pins the move (Rule 2).
  - `[low]` `[defer]` intent-alignment: the browser spec's frame is the harness's element, not the component's (reading R2); same root cause as the deferred item above.
  - `[false]` `[reject]` intent-alignment: only a DTL frame goes through the sign-out test - AC3 is stated for a DTL frame, and the mechanism it exercises, the shell gate plus the Bearer-and-cookie logout, does not depend on the editor.
  - `[low]` `[reject]` intent-alignment: no run opens a present class (200) - the spec's Tasks name a document the test never creates, and the 200 is cited as measured at the plan; the request clause is what AC1 pins.
  - `[medium]` `[patch]` intent-alignment: no scan exists for "listens for a frame's messages" - same root cause as the first row, closed by the same patch.
  - `[low]` `[reject]` intent-alignment: the frames and vendor-key bans match literals only - the spec's Tasks fix those patterns, and a bare `frames` cannot be banned (`shell/code-block.ts` holds `this.frames`).
  - `[low]` `[reject]` intent-alignment: the namespace-switch row's `pagehide` clearing has no test of its own - it is the vendor's behavior, measured at the plan, and the sign-out test's "no `_Editor-` key" clause shows the keys cleared when the frame unloads.
  - `[false]` `[reject]` intent-alignment: `api.test.mjs` is rewritten rather than extended on a contended file - `git diff` of the merge base against `origin/OCU-1-epic18` touches none of `api.test.mjs`, `document-viewer.store.ts` or `strings.ts`; the loop's rule counter is a strengthening the spec's "extend both fixture tests" allows.

## Design Notes

**Governing ADs:**

- AD-63, all five limits and the named consequence.
- AD-28: the sign-out path is unchanged, with the Bearer and the cookie. The pair is per tab, travels only as a header, and is never posted into a frame.
- AD-47: the origin is a trust boundary; the content-security policy is unchanged; there is no cross-tab broadcast and no runtime evaluation.
- NFR-3.
- AD-21: no path or parameter from a person's text; a closed vocabulary and checked shapes.
- AD-11: `src` through `Renderer2`.
- AD-19: zoneless, signal inputs, no component-held screen state.
- AD-20: the component makes no API call.

Checked and not engaged:

- AD-5, AD-8, AD-44 and AD-64: no screen, gate or classic page. Story 20.7's editor screens declare theirs.
- AD-62: OcuPilot calls nothing of `%Api.InteropEditors`; the vendor's own client in the frame does, as the person.
- AD-22 and AD-36: no write, key or read.
- AD-57: no try-it console.

**Measured at this plan on `ocupilot-b-ci`, 2026-10-12** (puppeteer's pinned Chrome, the signed-in shell at `?ns=HSCUSTOM`, a frame appended to `app-screen-outlet`; every session signed out after):

- **Sign-in.** All three editors signed in silently. Each made one login with a `null` body (200), then its info, mode and source-control reads (200). There was no password field, no CSP console error, zero messages in the shell and the frame, and `vscodeMode` was null. localStorage held only `ISC-language` and `searchTerm`.
- **Storage.**
  - Each editor wrote `<App>-0-{accessToken,refreshToken,user}`. Its token was not OcuPilot's, and OcuPilot's pair was unchanged.
  - Removing the frame cleared its keys (`pagehide`).
- **Document parameters.** `DTL=<class>` and `BP=<class>` opened present vendor classes. An absent name in each of `rule`, `DTL` and `BP` requested `/rules/<name>`, `/dtl/<name>` and `/bpl/<name>`, each answering 404.
- **Sign-out with a frame mounted.** No frame was left and no editor key was left. The empty editors login, the held editor access token and the held refresh token each answered 401.
- **Over the wire (curl).**
  - OcuPilot's logout revokes the editors' pair minted from the same login; access and refresh answer 401.
  - The editor's own Logout (Bearer and cookie) ends the browser-level login and OcuPilot's pair: OcuPilot's API, refresh and silent login answer 401.
  - The editor's idle `revoke` does not end OcuPilot's session.
- **History.** DTL and BPL each pushed two entries into the tab's history; the rule editor pushed none.
- **Opened tabs.** A tab the frame opened with `window.open` and no `noopener` received a copy of the tab's sessionStorage, with OcuPilot's pair, and a live `opener`. After sign-out the copied access and refresh tokens answered 401.
- **Headers.** `/ui/interop/rule-editor/index.html` sends no `X-Frame-Options` or CSP.

**Decisions:**

- **Integration AC: no consumers in this story; the first consumer is Story 20.7.** The mechanism is proved against the real editors in a test harness: the real signed-in shell on the throwaway, with a frame the spec builds from the shipped `interopEditorSource` inside the routed screen's host. That is where 20.7's screens will mount the component, and it is what sign-out withholds.
  - *Rejected, a minimal real embed:* it is 20.7's first editor screen (descriptor, rail, rosters, strings, prompts).
  - *Rejected, an Angular harness page:* the `harness` build is served from a loopback origin, which shares neither the instance's origin nor its `SameSite=Strict` cookie.
  - *Named limit:* the Angular component first runs in a real browser in 20.7. Until then `interop-editor-frame.spec.ts` pins its element exactly. 20.7's browser spec re-runs `interop-editor-spec.mjs`'s assertions against its real screens.
- **Sign-out needs no code change.** The shell already withholds every screen, and so every frame, whenever it is not signed in. AD-28's Bearer-and-cookie logout revokes the editors' pairs. This story pins both.
- **Deliberately not built, handed to 20.7:**
  - putting the source back after the editor navigates its own frame (its logo, "Back to standard UI");
  - the history entries DTL and BPL push;
  - the vendor's own sign-in form after a login ended elsewhere.

  Each is a screen-level behavior, and none needs OcuPilot to read the frame.
- **Guards strengthen and nothing loosens.** The content-security policy, `index.html`, its nonce, `build-output.test.mjs` and every header stay as they are. `api.test.mjs` gains four bans.
- **Rule 2 and Rule 31:**
  - `vendor-frame.ts` takes the sibling store's two shapes rather than copying them.
  - The component follows `DocumentViewerPage`'s frame (namespace on screen, `Renderer2`, `afterRenderEffect`) as its own small component rather than a shared base. The two frames differ by design: sandboxed, restoring and inert against unsandboxed and self-signing-in. The sibling also lives inside Epic 19's page.
  - The browser helper reuses `signedInAt` and `waitForMapAnswered`.

**Gate rulings (lead, 2026-10-12):** Q1 is asked of the orchestrator; the plan is the same either way. The spine drafts are written into AD-63 except the opened-tab sentence, which waits on Q1. No consumers in this story; the first consumer is Story 20.7.

**Gate question for the orchestrator (non-blocking; the plan is the same either way):**

- **Q1: tabs the editors open.**
  - The editors' help, "Open in Zen" and cross-editor buttons call `window.open(…, "_blank")` without `noopener`, and the browser copies the tab's sessionStorage, OcuPilot's pair included, into the new tab (measured).
  - This is AD-63's named consequence in action: the frame can read the pair and script the shell. The copy gives the opened same-origin page nothing it cannot mint itself, and sign-out revokes it (measured). OcuPilot cannot prevent it within AD-63: blocking it means sandboxing, which fails limit 5, or reaching into the frame, which fails limit 3.
  - **Options:** (A) record it in AD-63's named consequence (recommended); (B) a later story measures `Cross-Origin-Opener-Policy: same-origin` on the shell document, which may sever the opener and the copy (inference, unmeasured). That would edit `StaticHandler` and `Static.cls`, and it strengthens rather than weakens.

**Spine drafts (Rule 20; the runner writes them at the spec gate).** AD-63, add-only (Epic 18's pending spine edits are AD-17 and the Retention row):

- After limit 1: "The source is built only by `interopEditorSource` (`ui/src/app/core/vendor-frame.ts`) from a closed vocabulary of editors and each one's own document parameter (`rule`, `DTL`, `BP`; Story 20.13, measured). A new `/ui/interop` app joins it once its parameter is read on the instance (Story 20.8)."
- Limit 4: "Measured again at Story 20.13's plan: the sign-out also revokes each editor's own pair (its access and refresh tokens answer 401). The shell withholds every screen, and so every frame, whenever it is not signed in, and each editor clears its own keys on `pagehide`."
- Named consequence, appended: "The editor's own Logout ends the browser-level login and OcuPilot's pair with it (measured), as AD-28 already says of OcuPilot's own sign-out. OcuPilot then shows its session-ended card at its next request, and until then the editor may show its own sign-in form, which OcuPilot never fills or reads. A tab an editor opens without `noopener` receives a copy of the tab's storage, the pair included (measured); sign-out revokes it (measured)." The last sentence depends on Q1.

**Integration ACs, Consumes and Consumed-by:**

- No consumers in this story; the first consumer will be Story 20.7. AC1 and AC3 run against the real editors on `ocupilot-b-ci`.
- Consumes:
  - AD-28's sign-out (`Session.signOut`, Story 1.7) and the shell gate (`app.ts`);
  - `ScopeService`;
  - Story 19.9's frame pattern and shapes.
- Consumed-by:
  - 20.7: the three editor screens mount `app-interop-editor-frame` and reuse `interop-editor-spec.mjs`.
  - 20.8: schema viewers and the configuration diagram join `INTEROP_EDITORS` once their parameter is established.
  - 20.10: source control inside the framed editors.
  - 20.16: a reload re-sets the source (inference).

**Ledger inbox (Rule 17):** DW-2141 is addressed by the first Tasks item and AC1 to AC4.

**Contended files (Rule 11).**

- `origin/OCU-1-epic18`'s pending changes since the merge base touch none of this story's files except the spine (AD-17 and Retention).
- This story's edits to `strings.ts`, EXPERIENCE.md:604 and the spine are additions.
- `document-viewer.store.ts` (Epic 19's, uncontended) is outside Epic 20's footprint: a `footprint_extensions` entry.
- Security surfaces touched: `api.test.mjs`'s bans only, and they are tightened. No content-security policy, `frame-src`, header, `index.html` or nonce change.

**Strings and weight.**

- **Strings:** three literals, about 3,270 to 3,273, under the 3,350 point that triggers raising the bound.
- **Weight:** the component is imported by nothing in this story, so the build drops it (inference). `STRINGS` grows by under 0.1 kB, so the bundle is about 3,405,519 B plus less than 1 kB, under `maximumWarning` 3527 kB. If the build crosses it anyway, re-base under DW-1166.

## Verification

**Shared surfaces:**

- `api.test.mjs`'s `FORBIDDEN` list and its two fixture arrays
- the `strings.ts` key set, the EXPERIENCE.md:604 Fixed-strings row and `strings.test.mjs`'s derived counts
- `document-viewer.store.ts`'s shapes, now imported

No screen, rail, roster, descriptor, entity type, governance key or ObjectScript surface changes.

*Every test added or changed passes on a freshly built instance, in either order.*

**Setup (slot B):**

- Before any browser run: `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`.
- No ObjectScript changes, so no load is needed. For the `Static` mutation only:
  1. Run `rsync -a --checksum --delete /Users/jbrandt/git/OcuPilot/.worktrees/epic-20/src/ /Users/jbrandt/.ocupilot-throwaways/ocupilot-b-ci/src/`.
  2. Mutate the copy.
  3. In `docker exec -i ocupilot-b-ci iris session iris -U HSCUSTOM`, run `$System.OBJ.LoadDir("/opt/ocupilot/src/OcuPilot","ck-d",.tErrors,1)`.
  4. Re-sync and reload to revert.
- Never use the dev instance `ocupilot-slot-b`.

**Commands** (each in the foreground with `timeout: 600000`):

- `(loop)` `cd ui && npm run test:tools`. Expected: green, including `vendor-frame.test.mjs`, `api.test.mjs` and `strings.test.mjs`.
- `(loop)` `cd ui && npm run test:components`. Expected: green, including `interop-editor-frame.spec.ts` and `document-viewer.page.spec.ts`.
- `(loop)` `cd ui && OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci node --test --test-concurrency=1 browser/<file>`, one file per call. Expected: green.
  - `interop-editor-frame.browser-spec.mjs`
  - `system-explorer-documatic.browser-spec.mjs` (its shapes moved)
  - `account-and-filter.browser-spec.mjs` (the existing sign-out pin)
- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.Static`. Expected: green, read from `%UnitTest_Result`.
- `(loop)` `bash scripts/lint-docs.sh`. Expected: clean.
- Runner-owned, not the implement stage's:
  - the full ObjectScript sweep;
  - `cd ui && npm test && npm run build`, with the bundle measured against the weight note;
  - `bash scripts/smoke.sh --container ocupilot-b-ci --user _SYSTEM --password SYS`;
  - Rule 30's fresh check.
- `(CI)` the full browser suite, including the DW-1337 structural walk. No screen changes, so the walk is unchanged.

**Planned pinning mutations (Rule 19).** Run them on the throwaway, rebuilding and redeploying the bundle for the browser ones. Revert byte-identical.

| AC | Mutation | Expected red |
|---|---|---|
| AC1 | `interopEditorSource` appends `&VSCODE=1` | the browser spec's sign-in test (no login POST; `vscodeMode` set), `vendor-frame.test.mjs` |
| AC2 | `Session` writes `Rule_Editor-0-accessToken` into sessionStorage after sign-in | `api.test.mjs` (`_Editor-`), and the browser spec's before-mount keys |
| AC2 | `ContentSecurityPolicy` gains `frame-src *` | `OcuPilot.Test.Static`'s exact-policy test |
| AC2 | the component reads `frame.contentWindow` | `api.test.mjs` |
| AC3 | `Session.signOut()` posts `/logout` with `credentials: 'omit'` | the browser spec's sign-out test (the empty-body editors login answers 200) |
| AC4 | the template gains `sandbox=""` | `interop-editor-frame.spec.ts` attributes test |
| AC4 | `interopEditorSource` accepts a document holding `&` | `vendor-frame.test.mjs` refused-shape rows |
| AC4 | the component builds its own `/ui/interop/…` address | `vendor-frame.test.mjs`'s one-source scan |
| AC4 | the component draws while its namespace differs from the scope's | `interop-editor-frame.spec.ts` |

**Applied mutations (Rule 19).** Each was reverted byte-identical (`git status --short`, `git diff --stat` and file checksums equal before and after). A client mutation that a browser run reads was rebuilt and redeployed to `ocupilot-b-ci`, and the clean bundle was redeployed after.

- mutation: `interopEditorSource` appends `&VSCODE=1` -> `vendor-frame.test.mjs` red (exact sources, encoding, no-extension row, refused documents, no-VSCODE row); `api.test.mjs` source scan red (`\bVSCODE\b`); the browser spec red in all four tests (the editor posts no login and stores no token).
- mutation: `Session.adopt` writes `Rule_Editor-0-accessToken` into sessionStorage -> `api.test.mjs` source scan red (`_Editor-`); the browser spec's three AC1/AC2 subtests red on the before-mount keys, and the AC3 test red on a key left after sign-out.
- mutation: `StaticHandler.ContentSecurityPolicy` gains `frame-src *` (rsync copy, mutated, `$System.OBJ.Load` of that one class in the throwaway) -> `OcuPilot.Test.Static` red (`TestShellRootServesTheDocumentWithItsPolicyAndCacheHeaders`, 1 of 17); the browser spec's three AC1/AC2 subtests red on the policy equality. Reverted by re-sync and reload; `Static` green again (run 653).
- mutation: the component reads `frame.contentWindow` -> `api.test.mjs` source scan red.
- mutation: `Session.signOut()` posts `/logout` with `credentials: 'omit'` -> the browser spec's AC3 test red; the empty-body editors login, the held access token's v7 call and the held refresh token's refresh each answer 200, so each of the three 401 clauses is load-bearing.
- mutation: the harness mounts the frame in `document.body`, outside the shell's gate -> the browser spec's AC3 test red on "no frame remains".
- mutation: the template gains `(load)="drawn"` -> `interop-editor-frame.spec.ts` listener test red (a `load` listener on the frame); the component gains `@HostListener('window:message')` -> the same test red (a `message` listener) and `api.test.mjs` source scan red.
- control: the browser spec's policy watcher is shown to fire (a `fetch` the shell's policy refuses is reported to it), so "no content-security-policy violation" can fail.
- mutation: the template gains `sandbox=""` -> `interop-editor-frame.spec.ts` attributes test red.
- mutation: the document shape check is removed from `interopEditorSource` -> `vendor-frame.test.mjs` refused-documents and no-VSCODE rows red.
- mutation: the component sets its own `/ui/interop/${editor}/index.html` address -> `vendor-frame.test.mjs` one-source scan red.
- mutation: the component draws while its namespace differs from the scope's -> `interop-editor-frame.spec.ts` namespace test red.
- mutation: the title binding is removed -> `interop-editor-frame.spec.ts` red (two tests: the attributes test and the editor-change test).
- mutation: the `window.frames` ban, or the `vscodeMode` alternative, is removed from `FORBIDDEN` -> `api.test.mjs` fixture tests red (hostile list and scan fixture).
- mutation: `interopRuleEditorTitle` is changed to `Rule Editor` -> `strings.test.mjs` red (table literal, authorized-values and line-reference tests).
- mutation: `document-viewer.store.ts` keeps its own `NAMESPACE_NAME` -> `vendor-frame.test.mjs` moved-shapes row red.
- mutation: the component writes a sessionStorage key after setting `src` -> `interop-editor-frame.spec.ts` storage test red.

## Auto Run Result

Status: done
Blocking condition: none

**Implemented change.** AD-63's frame, with no change to sign-in, sign-out, the token store, the content-security policy, `index.html` or any header. `core/vendor-frame.ts` (framework-free) holds `interopEditorSource`, the closed `INTEROP_EDITORS` vocabulary (`rule`, `DTL`, `BP`) and the two shapes moved out of the class reference's store. `app-interop-editor-frame` draws one unsandboxed `<iframe>` only while its namespace is the one on screen and the builder answers, sets `src` with `Renderer2`, and reaches nothing in the frame. Three frame-title strings are in `strings.ts` and the EXPERIENCE.md:604 row.

**Files changed.**

- `ui/src/app/core/vendor-frame.ts` (new): the builder, vocabulary and shapes.
- `ui/src/app/areas/interoperability/interop-editor-frame.ts` (new): the component.
- `ui/src/app/areas/system-explorer/document-viewer.store.ts`: imports the two shapes instead of holding copies.
- `ui/src/app/core/strings.ts`, `EXPERIENCE.md`: the three titles (add-only; no new EXPERIENCE.md line).
- `ui/tools/api.test.mjs`: five new bans (frame reads, `window.frames`, message listeners, `VSCODE`, vendor storage keys), each with hostile and scan fixture lines and a check that every rule has a hostile line.
- `ui/tools/vendor-frame.test.mjs` (new): exact sources, encoding, refused shapes, moved shapes, the one-source scan.
- `ui/src/app/areas/interoperability/interop-editor-frame.spec.ts` (new): attributes, refusals, scope gate, re-set `src`, storage, listeners.
- `ui/browser/interop-editor-spec.mjs`, `ui/browser/interop-editor-frame.browser-spec.mjs` (new): the shared editor assertions and the real-editor spec on `ocupilot-b-ci`.

**Review.** Two layers, 15 findings: 2 medium, 11 low, 2 false. Patched: the message-listener gap (one root cause, two rows), AC3's three-clause assertion and the policy watcher's positive control. Deferred: 1 (the component's first real-browser run is Story 20.7). Rejected with reasons: 9 (see the Review Triage Log). The 14 recorded pinning mutations and the three added this pass are in `## Verification`; each was reverted byte-identical, and the throwaway holds the clean bundle (`main-XIZQM6QR.js`).

**Follow-up review:** not recommended (`false`): one medium entry patched and no high.

**Verification (this pass, final tree).**

- `npm run test:tools`: 1928 passed.
- `npm run test:components`: 2971 passed in 239 files.
- Browser, one file per call on `ocupilot-b-ci`: `interop-editor-frame` 5 passed, `system-explorer-documatic` 4 passed, `account-and-filter` 4 passed.
- `ci-runner` on `OcuPilot.Test.Static`: 17 tests, 0 failed (run 655).
- `scripts/lint-docs.sh`: clean.
- The build's initial total is 3,405,631 B, under `maximumWarning` 3527 kB. Runner-owned and not run here: the full ObjectScript sweep, `npm test && npm run build` as the gate, the smoke and Rule 30's fresh check.

**Residual risk.** The component itself first runs in a browser in Story 20.7; until then its element is pinned in jsdom and the real editors are proved through a harness frame built from the shipped builder. Q1 (tabs an editor opens with `window.open`) stays with the orchestrator and changes no code here.

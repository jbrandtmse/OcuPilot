---
title: 'Story 4.6: Replies render safely and offline'
type: 'feature'
created: '2026-09-17'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-4-context.md'
  - '{project-root}/_bmad/custom/skill-rules.md'
warnings: ['oversized']
deferred:
  - summary: 'DESIGN.md gives reply code blocks a copy icon button; this story does not build one.'
    evidence: 'DESIGN.md `message-agent` ("code blocks ... with a copy icon button"). No AC in Story 4.6 asks for it; it needs a new Fixed-strings row ("Copy") plus a non-secure-context clipboard fallback, and EXPERIENCE.md has no copy row today. Deferred to keep this story to its ACs.'
    location: 'ui/src/app/shell/reply.ts'
    severity: 'low'
  - summary: 'GFM tables in a reply render as their literal Markdown source, not as a table.'
    evidence: 'Decision D7 below. `marked` lexes a pipe table as one `table` token; the renderer emits `token.raw` as text so nothing is dropped. A real table needs the 2D-scroll exception (EXPERIENCE.md Accessibility Floor) and column styling neither contract specifies.'
    location: 'ui/src/app/core/reply.ts'
    severity: 'low'
  - summary: 'Release 1 highlighting is structural (weight and slant), because DESIGN.md publishes no syntax palette.'
    evidence: 'Decision D3 below. `hljs-*` classes are emitted, so adding color later is a CSS-only change; adding it now means new DESIGN.md token rows and contrast rows, which DESIGN.md owns.'
    location: 'ui/src/styles/_components.scss'
    severity: 'low'
  - summary: 'The built-in system prompt never asks the model to name rows in backticks or to offer to select them, so AC6''s "offers to select them" half has no producer.'
    evidence: '`src/OcuPilot/Kernel/Agent/Prompt.cls` `BUILTIN` says nothing about Markdown or citations. Story 4.7 owns the selection tool, so the offer only becomes true there; a prompt that offers it now promises what the agent cannot do. Belongs on Story 4.7.'
    location: 'src/OcuPilot/Kernel/Agent/Prompt.cls'
    severity: 'med'
---

<intent-contract>

## Intent

**Problem:** A reply renders today as one plain-text `<p>` (`panel.ts` `ocu-panel-message-agent-text`), so code, lists and citations read as an undifferentiated blob — and the render path that will present model-authored text has never been built under the rule that it must be incapable of reaching off the instance. EXPERIENCE.md `message-agent` and DESIGN.md `message-agent` both publish sanitized Markdown with code highlighting, inert external links showing their host, and same-origin-only images.

**Approach:** Parse the reply into a **plain-data node tree** in framework-free `core/`, then build DOM from that tree in a small `shell/` component — so no HTML string is ever produced or parsed and AD-11 rule 4's "markup-free by construction" stays literally true. Raw HTML inside a reply is text, never markup. Highlighting comes from `lowlight`, which answers a data tree (hast), not HTML. A final `DOMPurify` in-place pass over the built element is the vendored sanitizer and a second gate. Nothing server-side changes: the Content-Security-Policy this story is asked for already ships (`StaticHandler.ContentSecurityPolicy`), so AC5's work is to prove it refuses rather than to write it.

## Boundaries & Constraints

**Always:**

- **No HTML string, ever.** No `innerHTML`, no `DomSanitizer`, no `bypassSecurityTrust*`, no `marked.parse`/`marked.parser` — only `marked`'s `Lexer`. Every node is created with `createElement`/`textContent` from a closed tag and class allow-list (AD-11 rule 4, AD-33).
- **Nothing rendered from a reply may cause a request to any host.** An `<img>` is created only for a same-origin `src`; any other image renders as its alt text, else its literal source. Links carry `rel="noopener noreferrer nofollow"` and no `target`; `href` is allowed only for `http:`/`https:`/same-origin, and any other scheme (`javascript:`, `data:`, `vbscript:`, `blob:`, `file:`) renders the link as text.
- **Nothing is silently dropped.** A token the renderer does not model renders as its literal source text.
- `core/reply.ts` imports no `@angular/core` and touches no DOM or `location` (AD-19): the origin arrives as an argument. `DOMPurify` needs a `window`, so it lives only in `shell/reply.ts`.
- Colors come from tokens only (`client-lint.mjs` `no-hardcoded-color`); non-ASCII in TypeScript is `\uXXXX` (Rule 14); a citation of EXPERIENCE.md in source is the quoted-phrase form, never `EXPERIENCE.md:NNN` (`ui/tools/citations.test.mjs`).
- Parse once per distinct reply string and build DOM once per parse — the panel's `turns` getter runs on every change-detection pass.

**Never:**

- No change to `StaticHandler.ContentSecurityPolicy` or to `OcuPilot.Test.Static`'s exact-policy assertion: `img-src 'self'` stays, and no scheme source (`data:`) is added. No other ObjectScript change at all.
- No new user-facing literal, so no EXPERIENCE.md Fixed-strings row and no `strings.ts` key (see D6/D7 and `deferred:`).
- No click-through citation chips, no streaming/incremental append, no copy button, no GFM table rendering, no `highlightAuto` (it pulls every grammar).
- No CDN, no runtime-fetched stylesheet or grammar: the three libraries ship inside the bundle (NFR-10, AD-47).

## I/O & Edge-Case Matrix

`parseReply(text, { origin })` → `readonly ReplyNode[]`; the component builds DOM from it. "renders as text" means a text node, so `container.textContent` still holds the original characters.

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Plain one-line reply | `Here is what I found.` | one `p` whose text is the input; `container.textContent` equals the input, so Story 4.5's exact-equality assertions still pass | No error expected |
| Raw HTML | `<img src="http://203.0.113.9/x">` | one `p` whose **text** is that source; no `img` element; no request | No error expected |
| Remote Markdown image | `![a map](http://203.0.113.9/m.png)` | no `img` element; the alt text `a map` renders as text (empty alt → the literal source); no request | No error expected |
| Same-origin image | `![logo](/ocupilot/media/x.png)` | one `img` with that `src` and `alt`, `{rounded.md}` | No error expected |
| External link | `[docs](https://docs.example.com/p)` | `a` with that `href`, text `docs`, `rel="noopener noreferrer nofollow"`, no `target`, followed by a caption `span` whose text is exactly `docs.example.com`; no request until a click | No error expected |
| Hostile scheme | `[bad](javascript:alert(1))` | no `a` element; `bad` renders as text | No error expected |
| Fenced code, known language | a fenced block tagged `sql` holding `SELECT 1 -- c` | `pre > code.language-sql` on the code surface, containing `span.hljs-keyword` / `hljs-comment` spans; class names outside the allow-list are dropped | No error expected |
| Fenced code, unknown language | a fenced block tagged `objectscript` holding `Set x=1` | same `pre > code`, no `hljs-*` spans — `lowlight.registered()` is false, so no highlight is attempted | `lowlight.highlight` on an unregistered language throws; it is never called |
| Oversized code block | a fence over 20,000 characters | rendered as plain text on the code surface, unhighlighted | No error expected |
| Inline code / row citation | a reply naming two rows, each wrapped in single backticks | `code` spans in `{typography.code}` on `{colors.surface-container}`; plain text, no link, no chip (Epic 11) | No error expected |
| Entities and specials | `5 < 6 && "x"` | those exact characters (marked's Lexer yields unescaped text; nothing re-escapes) | No error expected |
| Lists, blockquote, emphasis | `- a\n- b`, `> q`, `**b**`, `*i*`, `~~s~~` | `ul/ol > li`, `blockquote`, `strong`, `em`, `del` | No error expected |
| Heading | `## Users` | a `p.ocu-reply-heading-2`, never `h1`–`h6` (D10) | No error expected |
| GFM table | a pipe table | the table's literal source as text (D7) | No error expected |
| Empty / whitespace reply | `''` | no nodes; the container stays empty and the panel renders no reply block (`turn.reply === null` already gates it) | No error expected |
| Turn ends in an error | `entry.error` set, state `failed` | unchanged from Story 4.5: the error banner `p.ocu-panel-error-banner[role=alert]` reads `"The turn stopped at <step>: <reason>."`; no reply block | No error expected |
| Turn the user stopped | state `stopped` | unchanged: no error banner (`turnErrorBanner` answers `null`), the halted card reads `"Stopped by you at <step>"` | No error expected |

</intent-contract>

## Code Map

- `ui/src/app/shell/panel.ts` — `panel.ts:183-188` is the reply block to replace (`<p class="ocu-panel-message-agent-text">{{ turn.reply }}</p>`); `panel.ts:189-194` is the error banner, which stays as built. `PanelTurnView` at `:40-45`, `turns` getter at `:467-476`, `imports` at `:87`. Every fact is a paren-free getter behind `generation()`; `@if` conditions must stay paren-free member references (`client-lint.mjs`).
- `ui/src/app/core/turn.ts` — `reply` is a wire `string | null` (`:220,225` restored; `:558-562,571-581` live), never transformed. `turnErrorBanner` at `:249-256` (returns `null` for `completed`/`stopped`, trims one trailing `.` off the reason); `stepLabel` at `:234`. Read-only here.
- `ui/src/app/shell/tool-call-card.ts` — the precedent for "every string renders through interpolation, never `innerHTML`" (`:10`); `STRINGS.toolCallStoppedByYou` substituted at `:95`. Read-only.
- `ui/src/app/core/strings.ts` — `agentTurnStoppedBanner` (`:173`) = `"The turn stopped at <step>: <reason>."`, `toolCallStoppedByYou` (`:171`). No copy/select/citation key exists and none is added.
- `ui/src/styles/_components.scss` — `.ocu-panel-message-agent` `:3484`, `.ocu-panel-message-agent-text` `:3501` (drop its `white-space: pre-wrap`; `breaks: true` now carries soft newlines as `br`), `.ocu-panel-error-banner` `:3509`, tool-card code surface `:3647`. Tokens `--ocu-code-surface`, `--ocu-on-code-surface`, `--ocu-surface-container`, `--ocu-on-surface-variant`, `--ocu-secondary` in `_tokens.scss:156-159`.
- `ui/src/app/shell/panel.spec.ts` — `:805` "markup in a reply renders as literal text" and `:837` its tool-call twin: both must stay green (the matrix's first two rows are why). `mount()` at `:109-177`, `fakeTurnApi` `:532`, `fakeTurnSchedule` `:548`, `turnStep` `:555`, `typeDraft` `:574`.
- `ui/browser/turn.browser-spec.mjs` — `:406-430` is the template for the off-origin-request assertion; `scriptReply(tag, hangSeconds, textReply(text))` (`:108-119`) scripts an arbitrary reply through the `turnprobe` provider over `docker exec`. **`escapeOs` only doubles quotes**, so a multi-line Markdown reply must be built as `"line"_$Char(10)_"line"` — add a `markdownReply(lines)` helper rather than embedding newlines.
- `ui/browser/shell.browser-spec.mjs:105-119` — the only console-error/`pageerror` collector in the repo; copy it.
- `ui/browser.config.mjs` — `browserConfig()` (`:56-68`), `launchOptions()` (`:72-82`), `LICENCE_PATH` (`:39`). No offline or interception option is set at launch; `page.setRequestInterception` is already used at `ui/browser/error-log.browser-spec.mjs:249-262`.
- `src/OcuPilot/Api/StaticHandler.cls` — `ServeIndex` `:234` sets the policy at `:264`; `ContentSecurityPolicy` `:348-351`; its doc comment `:340-347` is the standing reason no scheme source is added. `src/OcuPilot/Test/Static.cls:176` holds the exact expected policy. **Read-only in this story.**
- `ui/angular.json:51-57` — the only budget: `{"type":"initial","maximumWarning":"500kB","maximumError":"1MB"}`. `@angular/build`'s `BYTES_IN_KILOBYTE` is **1000** (`node_modules/@angular/build/src/utils/bundle-calculator.js:17,254-259`) and `initial` sums every chunk marked initial, JS and CSS (`:164-176`), raw bytes.
- `ui/tools/build-output.test.mjs` — the only test that runs a real `npm run build` (module scope, `:50-62`); notices byte-equality at `:127`, "no non-origin host in the emitted CSS or index.html" at `:224`. The bundle-size gate belongs here: the build is already paid for and `npm test` already runs it in CI's `gates` job at all three Node floors.
- `ui/tools/angular-json.test.mjs` — pins builders, `outputHashing`, assets, `baseHref`, the test target, the harness config, and puppeteer's exact pin (`:233-244`). It pins **no** budget today.
- `ui/tools/citations.test.mjs` — every EXPERIENCE.md citation in `ui/src` and `src/OcuPilot` must be `EXPERIENCE.md "quoted phrase"`; a `:NNN` form outside `strings.ts`'s gated comment fails it.
- Measured, not recalled (esbuild 0.28.2, the bundler `@angular/build` uses; `--bundle --minify --format=esm --target=es2022`): `marked` 44,361 B; `dompurify` 28,846 B; `lowlight` + `highlight.js` core + `sql`/`json`/`xml`/`bash` 38,870 B; all four in one entry **109,194 B raw / 37,854 B gzip**. Current emitted initial total **643,136 B** (`main-*.js` 545,333 + `styles-*.css` 97,803), so the error budget's remaining headroom is 356,864 B.

## Tasks & Acceptance

**Execution:**

1. `ui/package.json` — add four runtime dependencies at exact versions (`.npmrc` `save-exact=true`): `marked` `18.0.13` (MIT), `dompurify` `3.4.15` (MPL-2.0 OR Apache-2.0), `lowlight` `3.3.0` (MIT), `highlight.js` `11.11.2` (BSD-3-Clause). Refresh `package-lock.json` with `npm install`. **`highlight.js` must stay inside `~11.11.0`** — lowlight 3.3.0 declares that range, so 11.12.0 breaks the install. No ATTRIBUTIONS.md row: its `## npm dependencies` section delegates to the build's `extractLicenses` output, which `postbuild` copies into the served bundle.
2. `ui/src/types/highlight-js-languages.d.ts` — one ambient wildcard declaration typing `highlight.js/lib/languages/*` as `LanguageFn`; the package ships no per-language `.d.ts` (verified: TS 6.0.3 raises TS7016 the moment the import's type is consumed, and is clean with this declaration). Both `tsconfig.app.json` and `tsconfig.spec.json` include `src/**/*.d.ts`, so no tsconfig edit is needed; this is the tree's first `.d.ts`.
3. `ui/src/app/core/reply.ts` — new, framework-free and DOM-free. Export `ReplyNode` (a closed discriminated union: text, break, element with a closed `tag`, an allow-listed `classes` list, optional `href`/`src`/`alt`, children) and `parseReply(text: string, options: { origin: string }): readonly ReplyNode[]`, built on `new Lexer({ gfm: true, breaks: true })`. Own the URL policy, the class allow-list (`ocu-reply-*`, the `hljs-*` names the registered grammars emit, and `language-<name>` for exactly the four registered names), the 20,000-character highlight ceiling, and the "unmodelled token renders as its raw text" rule. Register exactly `sql`, `json`, `xml`, `bash` with `createLowlight`, guard every call with `registered(lang)`, and map lowlight's hast (`element`/`text` nodes only) into `ReplyNode`s.
4. `ui/src/app/shell/reply.ts` — new `app-reply` component, `OnPush`, one `input() text`, a `computed()` over `parseReply(text, { origin: location.origin })` and an `effect()` that builds the fragment once and appends it to its host in a single mutation (one announcement in the `role="log"` transcript), then runs `DOMPurify.sanitize(hostElement, { IN_PLACE: true, ALLOWED_TAGS: <the closed set>, ALLOWED_ATTR: ['class','href','src','alt'], ALLOW_DATA_ATTR: false, ALLOWED_URI_REGEXP: <http/https/relative> })`. **`IN_PLACE` requires an Element** — a `DocumentFragment` throws `'get attributes' called on an object that is not a valid instance of Element` (verified against 3.4.15) — so sanitize the host, not the fragment. DOMPurify strips `target` by default, which is the behavior this story wants (D5).
5. `ui/src/app/shell/panel.ts` — replace `:186`'s `<p>` with `<app-reply class="ocu-panel-message-agent-text" [text]="turn.reply" />`, keeping the class name so every existing selector and `textContent` assertion still resolves; add `Reply` to `imports`. Declare the input `input<string | null>()` and render nothing for `null` rather than relying on `@if` narrowing to satisfy `strictTemplates`. Nothing else in the panel changes — the error banner at `:189-194` stays exactly as Story 4.5 built it.
6. `ui/src/styles/_components.scss` — reply styles under `.ocu-panel-message-agent-text` (now a block host): paragraph rhythm, `br`, `strong`/`em`/`del`, lists, blockquote, the three heading weights, inline `code` in `{typography.code}` on `--ocu-surface-container` at `{rounded.sm}`, `pre > code` in `--ocu-on-code-surface` on `--ocu-code-surface` at `{rounded.md}` with `{spacing.3}` padding and its own scroll (the 1.4.10 two-dimensional exception), links `--ocu-secondary` underlined on hover with the host caption in `{typography.caption}` `--ocu-on-surface-variant`, images at `{rounded.md}` and `max-width: 100%`, and the `hljs-*` allow-list mapped to weight and slant only (D3). Drop `white-space: pre-wrap` from the container.
7. `ui/tools/reply.test.mjs` — new, `node --test`, importing `core/reply.ts` the way `turn.test.mjs:39` imports `core/turn.ts`. One test per I/O matrix row, plus: a class name outside the allow-list is dropped; `parseReply` never returns an element whose tag is outside the closed set; a 70,000-character reply is bounded rather than pathological.
8. `ui/src/app/shell/reply.spec.ts` — new, vitest + jsdom, following `proposal-card.spec.ts`'s single-component `TestBed` shape: the built DOM for each matrix row, `querySelector('img')` null for a remote image, no `a` for a hostile scheme, the host caption's exact text, the sanitizer pass removing an attribute the builder would never write (assert through a deliberately mutated tree, not by reaching into DOMPurify), and one parse per distinct text.
9. `ui/src/app/shell/panel.spec.ts` — keep `:805` and `:837` green; add the AC7 pins: an error entry renders the banner with `role="alert"` and the `agentTurnStoppedBanner` text in the agent slot, a `stopped` entry renders no banner and the halted card's `toolCallStoppedByYou`, and a reply plus an error never both render for one turn.
10. `ui/browser/reply.browser-spec.mjs` — new, following `turn.browser-spec.mjs`'s `turnprobe` scripting with a `markdownReply(lines)` helper: (a) a Markdown reply with a `sql` fence renders `pre > code` with at least one `span.hljs-keyword`, list items and an inline `code`; (b) a reply naming a remote image and a remote link produces **zero** requests to that host (`page.on('request')` hostname filter, the `:406` idiom) and creates no `img`; (c) with `page.setRequestInterception(true)` aborting every non-origin request, the same reply still renders completely — the proof that no library fetches anything; (d) the policy **refuses** rather than merely not being exercised: a `securitypolicyviolation` listener installed in the page, then `page.evaluate` attempting a remote `fetch()` and a remote `Image().src`, asserting the fetch rejects, two violations fire naming `connect-src` and `img-src`, and the request log stayed empty; (e) no console error or `pageerror` during the render (`shell.browser-spec.mjs:105-119`'s collector).
11. `ui/tools/build-output.test.mjs` — add the DW-371 gate: sum the emitted initial files (`browser/*.js` + `browser/*.css`, the same set `type: initial` sums) and assert the total is at or below `angular.json`'s `maximumWarning` parsed at 1000 bytes per kB, with a failure message naming the measured bytes, the budget and the two files to edit. Add: the served `3rdpartylicenses.txt` names `marked`, `dompurify`, `lowlight` and `highlight.js` — the artifact proof that the three roles ship inside the bundle.
12. `ui/tools/angular-json.test.mjs` — pin the budget literals (DW-371): exactly one `initial` budget, its `maximumWarning` and `maximumError` strings asserted verbatim, `maximumWarning` under `maximumError`; and assert every entry of `dependencies` and `devDependencies` is an exact `x.y.z` (the DW-215 precedent), with `highlight.js` inside lowlight's declared `~11.11.0`.
13. `ui/angular.json` — raise `maximumWarning` from `"500kB"` to the measured post-story initial total **rounded up to the next whole 20 kB** (expect ~`"780kB"`; a figure far from that is a signal to stop and look), leaving `maximumError` at `"1MB"`. Record the measured byte total in `## Auto Run Result`. The number now means something in three places: the build warns, `build-output.test.mjs` fails, and `angular-json.test.mjs` refuses a silent edit.

**Acceptance Criteria:**

- **AC1 (sanitized Markdown with highlighting).** Given a reply holding Markdown, when the panel renders it, then it renders as Markdown — paragraphs, emphasis, lists, blockquote, inline code, fenced code on the code surface with `hljs-*` token spans — and script and unsafe HTML are stripped before rendering, because no HTML string exists to parse: raw HTML renders as text and every element is created from a closed allow-list.
- **AC2 (vendored, no CDN).** Given the built bundle, when the page loads, then the renderer, highlighter and sanitizer are inside it — the served `3rdpartylicenses.txt` names all four packages — and a render completes with every non-origin request aborted at the browser.
- **AC3 (no request from a remote image).** Given a reply naming a remote image, when it renders, then no `img` element is created, no request to that host appears in the browser's request log, and an image renders only from a same-origin `src`.
- **AC4 (inert external link).** Given a reply holding an external link, when it renders, then the link carries the real `href`, `rel="noopener noreferrer nofollow"` and no `target`, the full host follows the link text as caption, and nothing is requested until the user clicks.
- **AC5 (the policy refuses).** Given the shell's Content-Security-Policy, when page script attempts a remote `connect` or a remote image, then the browser refuses it — a `securitypolicyviolation` event naming `connect-src` and `img-src`, a rejected `fetch`, and an empty request log — and `OcuPilot.Test.Static`'s exact-policy assertion still holds unchanged.
- **AC6 (row citations, Release 1).** Given a reply citing rows, when it renders, then the names appear as plain text in `code` on the inline code surface, with no link, chip or click target (Epic 11 adds those). The reply's offer to select them is the agent's own sentence; nothing in the client produces or rewrites it.
- **AC7 (error banner, and a stop is not an error).** Given a turn that ended in an error, when it renders, then the agent slot holds the error banner reading `"The turn stopped at <step>: <reason>."`; given a turn the user stopped, then no error banner renders and the halted card carries `"Stopped by you at <step>"`. Both are Story 4.5 behavior; this story pins them so the new render path cannot regress them.
- **AC8 (Rule 1, integration).** Given the panel — the consumer — when a turn's reply lands, then it renders through `app-reply` against a real instance in `ui/browser/reply.browser-spec.mjs`, observed as DOM and as an empty off-origin request log, never by inspecting `core/reply.ts`'s return value.
- **AC9 (DW-371).** Given a build, when `npm test` runs, then a gate compares the emitted initial total against `angular.json`'s `maximumWarning` and fails when it is exceeded, and a second gate refuses a silent edit to that figure.

## Spec Change Log

## Review Triage Log

## Design Notes

**Consumes:** Story 4.5's `core/turn.ts` (`reply`, `turnErrorBanner`, `TurnStep`) and `shell/panel.ts`'s transcript; Story 4.3's panel shell; Story 1.2's tokens and `strings.ts`; Story 1.5's `Api.StaticHandler` policy (read-only).
**Consumed-by:** Epic 11 — FR-71's click-through citation chips (they replace AC6's plain `code` spans) and streaming replies (an incremental-append mode over the same node tree); DESIGN.md's OpenAPI viewer reuses the same code-block treatment.
**Governing ADs:** AD-11 (rules 1 and 4), AD-33, AD-47, AD-19, AD-24, AD-12/AD-39 (the error banner's two renderings), AD-42 (nothing here widens egress).

**D1 — the package set** (a new runtime dependency is the lead's call; this is the named proposal). `marked` 18.0.13 for the Markdown lexer: 44.4 kB minified, zero dependencies, ESM, and its `Lexer` yields **unescaped** text (`5 < 6 && 7 > 3` arrives verbatim), so nothing double-escapes through `textContent`. `lowlight` 3.3.0 + `highlight.js` 11.11.2 for highlighting, 38.9 kB with four grammars: lowlight answers hast — plain objects, `span` elements and text nodes only — which is the one highlighter shape that never hands us an HTML string. `dompurify` 3.4.15 for the sanitizer, 28.8 kB, as the final in-place pass. Licences MIT / MIT / BSD-3-Clause / (MPL-2.0 OR Apache-2.0), all permissive and all covered by `extractLicenses`. Avoidable? `dompurify` is the one that is arguably redundant — in this design it guards a tree we built ourselves rather than one we parsed — but AC2 names a sanitizer among the three vendored artifacts, and 28.8 kB buys a second gate over the builder. `markdown-it` (1.97 MB unpacked, six dependencies) and `shiki` (WASM plus themes) were rejected on size; `prismjs` mutates the DOM through `innerHTML`.

**D2 — why this satisfies AD-11 rule 4.** "The rendering path is markup-free by construction" and "renders as sanitized Markdown" only coexist if Markdown never becomes HTML: the lexer yields tokens, we yield a data tree, the component yields DOM nodes. A `type: 'html'` token — anything the model wrote that looks like a tag — is a text node. That is also why Story 4.5's two existing assertions (`panel.spec.ts:805`, `turn.browser-spec.mjs:406`) keep passing rather than being rewritten: a single-paragraph reply's `textContent` is still the source string. `breaks: true` keeps the soft-newline behavior today's `white-space: pre-wrap` gave, as `br` elements; note that a multi-line reply's `textContent` therefore no longer contains its newlines, so a new assertion on multi-line output reads structure, not equality.

**D3 — highlighting is structural in Release 1.** DESIGN.md wins on color, and for the code surface it publishes exactly one pair (`{colors.on-code-surface}` on `{colors.code-surface}`), measures only that pair for contrast, rules teal out of it by name (Colors rule 3: "links inside a code block or the raw log view are `{colors.on-code-surface}`, underlined, not teal"), and forbids borrowing a status color out of its pair (rule 6). A syntax palette therefore needs new token rows and new contrast rows in a document this story does not own. So the highlighter runs, the `hljs-*` classes are emitted, and Release 1 styles a closed allow-list of them by weight and slant. Adding color later is a CSS-only change against classes that already exist (`deferred:`).

**D4 — no CSP change.** The policy already reads `default-src 'self'; script-src 'self'; style-src 'self' 'nonce-…'; img-src 'self'; font-src 'self'; connect-src 'self'; object-src 'none'; base-uri 'self'; form-action 'self'; frame-ancestors 'none'`, which is AC5 in full. `StaticHandler`'s own doc comment records why no scheme source is added: `data:` is not an origin, and AD-47 says the policy names only the instance's origin. So a `data:` image in a reply is **not** rendered as an image (its alt text renders instead) — "images render only from same-origin or inline sources" bounds what may render, and rendering strictly fewer needs no widening. The highlighter emits classes, never inline styles, so the nonce is not involved.

**D5 — links open in the same tab.** EXPERIENCE.md bans new windows everywhere except the classic-link-card and the OAuth classic editor, so a reply's link carries no `target`; DOMPurify strips `target` by default, so the two agree by construction. `rel="noopener noreferrer nofollow"` still travels, and "inert" means only that nothing happens without a click — no prefetch, no preload, no auto-activation.

**D6/D7/D8/D10 — bounded scope, each with a `deferred:` entry.** No copy button (DESIGN.md asks for one; it needs a new literal and a non-secure-context clipboard fallback, and no AC asks for it). No GFM table rendering. No prompt amendment. Markdown headings render as styled paragraphs, never `h1`–`h6`: model-authored text does not enter the document's heading outline, which is the same instinct as AD-11's "never as OcuPilot's own voice".

**D9 — the DW-371 answer, in full.** The figure is pinned rather than left to drift: `angular.json`'s `maximumWarning` becomes the deliberate post-story number (the build warns), `build-output.test.mjs` measures the emitted initial total against it (`npm test` fails, at every Node floor in CI's `gates` job), and `angular-json.test.mjs` asserts the literals (a silent raise fails). No `ci.yml` step is added, so `ci.test.mjs`'s `DECLARED_GATES` multiset is untouched. DW-296 — the ancestor entry, closed `wontfix-accepted` with `reopen_if=… a release story needs a budget that means something` — is what this satisfies.

**Performance.** `parseReply` runs once per distinct reply string inside `app-reply`'s `computed()`, not in the panel's `turns` getter, which runs on every change-detection pass. A code fence over 20,000 characters skips highlighting; the server already caps a reply at 65,536 characters (AD-24).

## Verification

**Commands** (from `ui/` unless stated):

- `npm run build` — expected: exit 0, `prebuild`'s six checkers pass, and the initial-total warning names the new deliberate figure rather than 500 kB.
- `npm test` — expected: `node --test tools/*.test.mjs` green including the new `reply.test.mjs` and the two DW-371 gates, then the vitest component runner green including `reply.spec.ts` and `panel.spec.ts`.
- `cd ui && npm run build` (the full script, so `postbuild` copies `3rdpartylicenses.txt`), then `docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/`, then `OCUPILOT_BROWSER_ORIGIN=http://localhost:52776 OCUPILOT_BROWSER_CONTAINER=ocupilot-ci npm run test:browser` — expected: every spec green, including the new `reply.browser-spec.mjs`. A browser spec reads the deployed bundle, so no browser result counts until this rebuild and copy have run.
- `bash scripts/smoke.sh --container ocupilot-ci --user _SYSTEM --password SYS` (repository root) — expected: a non-zero executed-check count, all passing. No ObjectScript changes, so `uv run scripts/check-objectscript.py` is a no-op check that must still pass.

**Falsifiability (Rule 19 — the pinning test and the mutation to record for each):**

- AC1 → `reply.test.mjs` "a fenced sql block highlights". Mutation: make `parseReply` ignore the `code` token's `lang` → the `hljs-keyword` assertion reddens.
- AC1 (unsafe HTML) → `panel.spec.ts:805` plus `reply.test.mjs` "raw HTML renders as text". Mutation: render an `html` token's children instead of its raw text → both redden.
- AC2 → `build-output.test.mjs` "the served notices name the four vendored packages". Mutation: drop `marked` from `dependencies` (or mock the bundle without it) → red. Plus `reply.browser-spec.mjs` (c): mutation — remove the interception abort and let a request through; the spec's own request-log assertion must still be the thing that fails, not the render.
- AC3 → `reply.browser-spec.mjs` (b). Mutation: allow a non-same-origin `src` in `core/reply.ts`'s image rule → an `img` appears and the off-origin request log is non-empty; the jsdom twin in `reply.spec.ts` reddens on the element alone.
- AC4 → `reply.spec.ts` "an external link carries its host as caption and no target". Mutation: drop the host caption span, or add `target="_blank"` → red (the `target` case reddens because DOMPurify removes it, which is the assertion).
- AC5 → `reply.browser-spec.mjs` (d). Mutation: serve the index without the `Content-Security-Policy` header (a throwaway-local edit to `ServeIndex`, reverted) → the two `securitypolicyviolation` assertions redden and the remote `fetch` resolves. Record that the working tree was byte-identical afterwards.
- AC6 → `reply.test.mjs` "an inline code span is a `code` element with no href and no click target". Mutation: render a codespan as an `a` → red.
- AC7 → `panel.spec.ts` "a stopped turn renders no error banner". Mutation: make `turnErrorBanner` answer the banner for `state === 'stopped'` → red (this is already `turn.test.mjs`'s recorded mutation; the panel-level pin is the surface half).
- AC8 → `reply.browser-spec.mjs` (a), which observes the panel, not the parser. Mutation: leave `panel.ts` rendering the old `<p>{{ turn.reply }}</p>` → the `pre > code` assertion reddens while every `core/` test stays green, which is the point.
- AC9 → `build-output.test.mjs`'s size gate. Mutation: lower `maximumWarning` by 1 kB below the measured total → red naming both numbers.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none. Plan stage only; the story is not implemented.

This pass planned the story from the epics text, the spine (48 ADs), EXPERIENCE.md, DESIGN.md `message-agent`
and the shipped client. Verified rather than recalled, in a scratch directory outside the worktree: the four
packages' versions, licences and minified sizes (esbuild 0.28.2); that `marked`'s `Lexer` yields unescaped
text and lexes raw HTML as an `html` token; that `lowlight` answers hast, throws on an unregistered language,
and emits only `span` elements; that `DOMPurify` 3.4.15's `IN_PLACE` needs an Element and strips `target`;
that `highlight.js` ships no per-language `.d.ts` (TS7016) and one ambient wildcard declaration fixes it;
that `@angular/build` counts a kB as 1000 bytes and sums initial JS and CSS; and the current emitted initial
total of 643,136 B. `bash scripts/lint-docs.sh` on this file: 0 problems. No ledger entry was created — under
Rule 15(a) this workflow records deferred findings in frontmatter `deferred:` and the lead harvests them.

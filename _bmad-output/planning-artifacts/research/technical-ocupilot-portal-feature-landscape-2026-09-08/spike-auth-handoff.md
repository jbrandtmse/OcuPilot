# Handoff: authentication spike for OcuPilot (Deepen round of D4 and D5)

**Written:** 2026-09-08 by the Deep Recon lead (Mary, business analyst persona) at the project owner's request.
**Run as:** a fresh-context agent session in the OcuPilot repository. Read this file first, then `research.md` sections D4 and D5 in this folder, then the two digests named below. Do not read the rest of the run folder unless a step here says so.
**Time box:** about 40 tool calls or two hours. If the budget runs out, write what you have (see Deliverable) and stop; a partial verdict with exact observations beats a complete guess.

## 1. Why this spike exists

Every REST application on the IRIS instance keeps its own session cookie path with SameSite Strict, so an Angular app served by its own web application does not automatically share a login with `/api/admin`, `/api/interop-editors` or `/api/atelier` (research.md, D4, "Auth and session model"; `digests/api-coverage-r1-1.md`). InterSystems' own Angular editors under `/ui/interop` nevertheless log in silently when the browser already holds a classic-portal session: they POST an empty body to `/api/interop-editors/login` and receive a JWT. The only visible common factor is that `/csp/sys`, `/ui/interop`, `/api/interop-editors` and `/api/admin` all carry `GroupById=%ISCMgtPortal`, a setting the documentation says not to use, while the cookie that carries the silent login was never isolated: forcing `IRISSessionToken` alone, or the `/csp/sys` session cookie, or `CSPCHD`, through curl all returned 401 (`digests/irisui-embed-r1-1.md`, "Session / auth hand-off").

The project owner has decided the vendor's own mechanism (Group by ID plus JWT) is acceptable for the contest. The spike must establish, with observations rather than inference, what OcuPilot's web applications need so that (a) its screens can call the admin and interop APIs with the user's login, (b) the vendor's Rule, DTL and BPL editors load inside an OcuPilot iframe and log in silently, and (c) the same works when OcuPilot is the first thing the user opens, with no classic-portal login beforehand.

Outcome consumers: the architecture document (authentication decision, web-application settings), the PRD (login and session requirements), and catalog rows SH-01, SH-10, CP-02, PK-11, PK-12 in `feature-catalog.md`.

## 2. What is already established (do not re-verify; cite by pointer)

| Fact | Where established |
| --- | --- |
| Web-application settings observed live: `/csp/sys` AutheEnabled 96 (password + unauthenticated), CSRFToken 1, GroupById `%ISCMgtPortal`, cookie path `/csp/sys/`; `/ui/interop` AutheEnabled 64, GroupById `%ISCMgtPortal`, CSRFToken 1; `/api/interop-editors` and `/api/admin` AutheEnabled 32, JWTAuthEnabled 1, GroupById `%ISCMgtPortal`, `UseSession=0`, own cookie paths; `/api/atelier` AutheEnabled 32, no JWT, no group, `UseSession=1`, cookie path `/api/atelier/`; all SessionScope 2 (SameSite Strict) | `digests/api-coverage-r1-1.md`, "Auth and session model"; verified in `digests/api-coverage-r1-verify.md` (C1, C7) |
| Cookies seen after a portal login: `CSPSESSIONID-SP-52774-UP-csp-sys-` (path `/csp/sys/`, httpOnly, SameSite Strict), `IRISSessionToken` (path `/`, httpOnly, SameSite Strict, set by a `/csp/hscustom` Zen page), `CSPWSERVERID` (path `/`); the interop-editors login sets `CSPBrowserId` (path `/`) | `digests/irisui-embed-r1-1.md`, "Session / auth hand-off" |
| `POST /api/interop-editors/login` with `{"user","password"}` returns an ES256 access token (60 s) and a refresh token (900 s) with claims `iss`, `sub`, `sid`, `app="/api/interop-editors/"`; the bundles store both in sessionStorage and send `Authorization: Bearer`; a 401 triggers a refresh; the same Bearer was accepted by `/api/security-config/...` (200) and rejected by `/api/atelier/` (401) | same digest |
| The `/ui/interop` static files are served unauthenticated with no X-Frame-Options and no Content-Security-Policy; only `/csp/sys/UtilHome.csp` sends `X-FRAME-OPTIONS: SAMEORIGIN` | same digest, "Headers that affect framing" |
| The rule, DTL and BPL editors have an embedded mode: `?VSCODE=1` skips the automatic login and accepts `window.postMessage({type:"auth", username, password})` from the parent; they post `saved`, `compiled`, `badrule/baddtl/badbpl` and `compatible` events back | same digest, "Embedded (VSCODE) mode" |
| The Rule Editor must be loaded at exactly `/ui/interop/rule-editor/index.html?$NAMESPACE=<ns>&rule=<class>`; its API root is derived from `/ui/interop` in its own URL | same digest, "Serving constraints" |
| The documentation says of Group by ID "Do not use. This field is for migrated legacy applications only" while Documatic describes it as synchronized authentication across applications in a group | `irisdocs/guides/GSA_manage_applications.md` line 793 (local mirror); Documatic `Security.Applications` |
| `Security.Applications.Create()` may not notify the Web Gateway; a newly created web application can return 404 until it is saved once in the portal or the gateway restarts | `digests/harvest-execute-mcp-r1-1.md`, "Known gateway caveat" (README of iris-execute-mcp-v2) |

Read before testing: `irisdocs/guides/GSA_manage_applications.md`, the passages on "Group by ID", "Session Cookie Path", "Use Cookie for Session" and any "login token" or "JWT" text. Quote the lines that bear on the verdict.

## 3. Hypotheses to test

- **H1, shared session through Group by ID.** A page served by a web application in the `%ISCMgtPortal` group, opened in a browser that already holds a classic-portal login, can (a) `GET /api/admin/info` with `credentials: "include"` and no Authorization header and receive 200; (b) `POST /api/interop-editors/login` with an empty body and receive a JWT; (c) load the Rule Editor in an iframe and see it log in silently and render its toolbar.
- **H1-control.** The same page served by an identical web application without Group by ID behaves differently on (a), (b) or (c). If it behaves the same, Group by ID is not the carrier and the verdict must say what is.
- **H2, JWT-only path with no portal login.** In a clean browser context with no prior login: `POST /api/admin/login` with `{"user":"_SYSTEM","password":"SYS"}` returns a JWT (the built-in JWT endpoints of a JWT-enabled REST application sit on the application root, as `/api/interop-editors/login` does); that Bearer is accepted by `/api/admin/v2/namespaces`; the `/api/interop-editors` Bearer is or is not accepted by `/api/admin` (check the `app` claim binding both ways); `/api/admin/refresh` and `/logout` behave as documented.
- **H3, isolating the carrier.** In the logged-in browser, delete cookies one at a time (`IRISSessionToken`, `CSPWSERVERID`, `CSPSESSIONID-SP-52774-UP-csp-sys-`, `CSPBrowserId`) and repeat H1(b) after each deletion. The deletion that turns 200 into 401 names the carrier. Then reproduce the 200 with curl using exactly the surviving cookies together (the earlier attempt sent `IRISSessionToken` alone).
- **H4, the OcuPilot-first flow.** In a clean context, log in through the spike page itself (H2), then load the Rule Editor iframe: does it log in silently now, or does it need `VSCODE=1` plus a posted `auth` message? Record which.

## 4. Setup

1. **Rules that apply.** Every IRIS MCP call passes `server: "ocupilot-iris"` (omitting it silently routes to another container). Never load, compile or import anything under `irislib/`, `irissys/`, `irisui/` or `irisdocs/`. Write no ObjectScript for this spike; two static web applications are enough. Change nothing else on the instance, and undo everything you create (section 7).
2. **Instance.** `http://localhost:52774`, user `_SYSTEM`, password `SYS`, namespaces `HSCUSTOM` and `%SYS`; container service `iris` in `docker-compose.yml`. Confirm with `curl -s -o /dev/null -w '%{http_code}' -u _SYSTEM:SYS http://localhost:52774/api/admin/info` (expect 200).
3. **Test page.** Create the directory inside the container and copy the page in:

   ```bash
   docker compose exec -T iris mkdir -p /usr/irissys/csp/ocupilot-spike
   docker compose cp ./spike-index.html iris:/usr/irissys/csp/ocupilot-spike/index.html
   ```

   `spike-index.html` (write it to a scratch location first; it must contain no external requests):

   ```html
   <!doctype html><meta charset="utf-8"><title>OcuPilot auth spike</title>
   <style>body{font:14px system-ui;margin:1rem}pre{background:#eee;padding:.5rem;white-space:pre-wrap}iframe{width:100%;height:520px;border:1px solid #999}</style>
   <h1>OcuPilot auth spike</h1>
   <p id="app"></p>
   <button id="run">Run fetch tests</button>
   <button id="login">Login via /api/admin/login</button>
   <pre id="log"></pre>
   <iframe id="re" title="Rule Editor"></iframe>
   <script>
   const log = (m) => { document.getElementById('log').textContent += m + '\n'; };
   document.getElementById('app').textContent = 'Served from ' + location.pathname;
   let bearer = null;
   async function probe(label, url, opts) {
     try { const r = await fetch(url, Object.assign({credentials:'include'}, opts||{}));
       const txt = await r.text(); log(label + ' -> ' + r.status + ' ' + txt.slice(0,160).replace(/\s+/g,' ')); return r; }
     catch (e) { log(label + ' -> ERR ' + e); }
   }
   async function run() {
     await probe('GET /api/admin/info (cookies only)', '/api/admin/info');
     await probe('POST /api/interop-editors/login (empty body, cookies only)', '/api/interop-editors/login', {method:'POST'});
     await probe('GET /api/atelier/ (cookies only)', '/api/atelier/');
     await probe('GET /api/interop-editors/v7/HSCUSTOM/mgmt-url (cookies only)', '/api/interop-editors/v7/HSCUSTOM/mgmt-url');
     if (bearer) {
       await probe('GET /api/admin/v2/namespaces (Bearer)', '/api/admin/v2/namespaces', {headers:{Authorization:'Bearer '+bearer}});
       await probe('GET /api/interop-editors/v7/HSCUSTOM/mgmt-url (admin Bearer)', '/api/interop-editors/v7/HSCUSTOM/mgmt-url', {headers:{Authorization:'Bearer '+bearer}});
     }
     document.getElementById('re').src = '/ui/interop/rule-editor/index.html?$NAMESPACE=HSCUSTOM';
     log('iframe set; watch network for POST /api/interop-editors/login from the frame');
   }
   async function login() {
     const r = await probe('POST /api/admin/login {user,password}', '/api/admin/login', {method:'POST', headers:{'Content-Type':'application/json'}, body: JSON.stringify({user:'_SYSTEM', password:'SYS'})});
     try { const j = await r.clone().json(); bearer = j.access_token || null; log('bearer captured: ' + (bearer ? 'yes (' + bearer.split('.').length + ' parts)' : 'no')); } catch (e) { log('no JSON token in response'); }
   }
   document.getElementById('run').onclick = run;
   document.getElementById('login').onclick = login;
   </script>
   ```

4. **Two web applications** (create with the iris-admin MCP tool `iris_webapp_manage`, or with `iris_execute_command` in `%SYS`):

   | Name | NameSpace | Path | ServeFiles | AutheEnabled | GroupById | Enabled |
   | --- | --- | --- | --- | --- | --- | --- |
   | `/ocupilot-spike` | `HSCUSTOM` | `/usr/irissys/csp/ocupilot-spike/` | 1 | 64 (unauthenticated, like `/ui/interop`) | `%ISCMgtPortal` | 1 |
   | `/ocupilot-spike-nogroup` | `HSCUSTOM` | `/usr/irissys/csp/ocupilot-spike/` | 1 | 64 | (empty) | 1 |

   ObjectScript form, if the tool does not expose every property (run in `%SYS`; one statement per call):

   ```objectscript
   Set p("NameSpace")="HSCUSTOM",p("Path")="/usr/irissys/csp/ocupilot-spike/",p("ServeFiles")=1,p("AutheEnabled")=64,p("GroupById")="%ISCMgtPortal",p("Enabled")=1 Set sc=##class(Security.Applications).Create("/ocupilot-spike",.p) Write $System.Status.GetErrorText(sc)
   ```

   Then `curl -s -o /dev/null -w '%{http_code}' http://localhost:52774/ocupilot-spike/index.html` (expect 200). If 404, open Security > Applications > Web Applications in the classic portal, open the new application and save it once, then retry; record whether that was needed.

5. **Browser.** Use the chrome-devtools MCP tools (`list_pages`, `new_page`, `navigate_page`, `evaluate_script`, `list_network_requests`, `get_network_request`, `take_snapshot`). Use `new_page` with `isolatedContext` names to get clean cookie jars for H2 and H4; use the default context for H1 and H3 after logging into `http://localhost:52774/csp/sys/%25CSP.Portal.Home.zen?$NAMESPACE=HSCUSTOM` with `_SYSTEM` / `SYS`.

## 5. Procedure

1. **H1.** Default context: log into the portal, then `new_page` `http://localhost:52774/ocupilot-spike/index.html`, click "Run fetch tests", read the log with `take_snapshot` or `evaluate_script`, and read the iframe's network calls with `list_network_requests` (look for `POST /api/interop-editors/login` and its status, then `GET .../v7/HSCUSTOM/mgmt-url`). Record every status. Then take a snapshot of the iframe content: does the Rule Editor toolbar (New, Open, Save, Compile, Test) render, or a login form?
2. **H1-control.** Same steps on `http://localhost:52774/ocupilot-spike-nogroup/index.html` in the same logged-in context. Record differences.
3. **H3.** Still logged in: use `evaluate_script` to list cookies visible to the page (httpOnly cookies are invisible to script, so also read them from `get_network_request` response and request headers). Delete cookies through the DevTools protocol if the tool allows, otherwise through the portal logout and a fresh login between trials, and repeat only H1(b) each time. When the carrier is found, reproduce with curl:

   ```bash
   curl -s -o /dev/null -w '%{http_code}\n' -X POST -H 'Cookie: <the surviving cookies, all of them>' http://localhost:52774/api/interop-editors/login
   ```
4. **H2.** `new_page` with `isolatedContext: "clean-jwt"` to `http://localhost:52774/ocupilot-spike/index.html`; click "Login via /api/admin/login"; then "Run fetch tests". Record: does `/api/admin/login` exist (200 with a token, 404, or 401); is the admin Bearer accepted by `/api/admin/v2/namespaces`; is it accepted by `/api/interop-editors`; decode the token header and payload (base64) and record `app`, `sub`, `exp` minus `iat`. Also try `POST /api/admin/refresh` with the refresh token and `POST /api/admin/logout`.
5. **H4.** In the same clean context, after the H2 login, look at the iframe: did the Rule Editor log in silently? If it shows a login form, navigate the iframe to `...index.html?$NAMESPACE=HSCUSTOM&VSCODE=1`, post `{type:"auth", username:"_SYSTEM", password:"SYS"}` to it from the parent through `evaluate_script`, and record whether it renders and which events it posts back (`compatible`, then after a save attempt `saved` or `badrule`).
6. **Docs check.** Read the Group by ID and Session Cookie Path passages in `irisdocs/guides/GSA_manage_applications.md`; quote the two or three sentences that explain (or fail to explain) what you observed.

Stop-and-write valve: if H1 and H2 are answered and the budget is nearly spent, skip H3's curl reproduction and H4's VSCODE branch, and say so.

## 6. Pass and fail criteria

- **Shared-session path passes** if H1(a), (b) and (c) all succeed from `/ocupilot-spike` and at least one of them fails from `/ocupilot-spike-nogroup`. If both applications behave identically, Group by ID is not what carries the login; the verdict must name the actual carrier from H3.
- **JWT-only path passes** if `/api/admin/login` returns a token that `/api/admin/v2/namespaces` accepts. Whether the admin token is also accepted by `/api/interop-editors` decides whether OcuPilot needs one login or two.
- **Embedded editors pass** if the Rule Editor renders inside the iframe with no user interaction in H1, or with the `VSCODE=1` auth message in H4. Record which, because they have different security consequences (the second sends the password into the frame).
- **Recommendation to write:** the web-application settings OcuPilot's static app and REST app should declare (AutheEnabled bits, GroupById, JWTAuthEnabled, UseSession, CookiePath), which login endpoint the Angular shell calls, where the token lives, how refresh and logout work, and what the embedded editors need. If the evidence supports two viable designs, state both with the trade-off in one sentence each.

## 7. Cleanup (mandatory, even on failure)

```objectscript
Set sc=##class(Security.Applications).Delete("/ocupilot-spike")
Set sc=##class(Security.Applications).Delete("/ocupilot-spike-nogroup")
```

```bash
docker compose exec -T iris rm -rf /usr/irissys/csp/ocupilot-spike
```

Close the browser pages you opened (`close_page`), including the isolated contexts. Confirm with `iris_webapp_list` (server `ocupilot-iris`, namespace `%SYS`) that neither application remains.

## 8. Deliverable

1. Write `digests/auth-spike-r2-1.md` in this folder with: a verdict table (H1, H1-control, H2, H3, H4: pass / fail / partial, with the exact statuses observed); the request and response headers that decide each verdict, trimmed; the decoded JWT claims; the docs quotations; the recommended web-application settings table; the two-design trade-off if applicable; what you could not test and why. Every observation carries the URL, the method, the status and the context (logged-in default, clean-jwt, nogroup).
2. Append to the run's memlog through the script, never by editing the file:

   ```bash
   uv run _bmad/scripts/memlog.py append --workspace <this folder> --type event --text "Auth spike r2 landed: <one-line verdict>"
   uv run _bmad/scripts/memlog.py append --workspace <this folder> --type claim --text "ref=[22] status=<verified|overturned|disputed> class=api-coverage pub=2026-09 — <the auth-model claim as it now stands>"
   uv run _bmad/scripts/memlog.py append --workspace <this folder> --type claim --text "ref=[25] status=<verified|overturned|disputed> class=embeddability pub=2026-09 — <the silent-login claim as it now stands>"
   ```

3. Do not edit `research.md` or `feature-catalog.md`; the research lead integrates the digest (D4 auth paragraph, D5 mechanics, Open questions rows on the cookie carrier and the same-origin Atelier call, catalog rows SH-01, SH-10, CP-02, PK-11, PK-12). End your session with a summary of at most 250 words: the verdict per hypothesis, the recommended settings, and the digest path.

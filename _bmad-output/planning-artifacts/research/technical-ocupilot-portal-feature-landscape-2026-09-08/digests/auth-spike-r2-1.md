# Authentication spike — round 2 — 2026-09-08

**Handoff:** `../spike-auth-handoff.md` (Deepen round of D4 and D5). **Run by:** Mary (business analyst persona), fresh session, 2026-09-08 15:10–15:30 UTC. **Instance:** `http://localhost:52774`, IRIS for Health Community 2026.2 (container `ocupilot`, instance name `b066ba383583/IRIS` per the JWT `iss` claim), user `_SYSTEM`. **Method:** two throw-away static web applications (`/ocupilot-spike` with `GroupById=%ISCMgtPortal`, `/ocupilot-spike-nogroup` without; both `AutheEnabled=64`, `ServeFiles=1`, path `/usr/irissys/csp/ocupilot-spike/`), one static test page, curl, and Chrome through the chrome-devtools MCP with three browser contexts: **default** (classic portal login through the form), **clean-jwt** (isolated, no portal login, JWT login only) and **clean-portal** (isolated, classic form login only, no JWT login ever). Everything created was removed afterwards (section 9). No ObjectScript was written; nothing under `irislib/`, `irissys/`, `irisui/` or `irisdocs/` was loaded or changed.

## 1. Verdict table

| Hypothesis | Verdict | Exact observations |
| --- | --- | --- |
| **H1** shared session from a page in the `%ISCMgtPortal` group, portal already logged in | **Pass, with one correction** | (a) as written **fails**: `GET /api/admin/info` with cookies only → **401**; so do `GET /api/admin/v2/namespaces` and `GET /api/interop-editors/v7/HSCUSTOM/mgmt-url` (both 401). Cookies never authorize a data call on a `UseSession=0` JWT application. (b) **passes**: `POST /api/interop-editors/login` with an empty body and cookies only → **200** with an access and refresh token for `_SYSTEM`; `POST /api/admin/login` empty body → **200** likewise. (c) **passes**: the Rule Editor iframe issued `POST /api/interop-editors/login` (empty body) → 200, then `info`, `mgmt-url`, `system-mode`, `sourcecontrol/enabled` all 200, and rendered the toolbar New / Open / Save / Save As / Compile / Test with no login form. |
| **H1-control** same page from `/ocupilot-spike-nogroup` | **Identical to H1** | (a) 401, (b) 200 on both login endpoints, (c) editor rendered. **The serving application's Group by ID is irrelevant.** What carries the login is a `path=/` cookie (H3) plus the Group by ID of the *API* application being asked to mint. |
| **H2** JWT-only path, no portal login | **Pass** | `POST /api/admin/login` `{"user","password"}` → **200**, ES256 access token (60 s) and refresh token (900 s), `app="/api/admin/"`. Bearer → `GET /api/admin/v2/namespaces` **200**. Admin Bearer → `/api/interop-editors/v7/HSCUSTOM/mgmt-url` **200**; interop-editors Bearer → `/api/admin/v2/namespaces` **200**; both Bearers → `/api/security-config/credential/v1/credentials` **200**; a Bearer minted by `/csp/fhirsql/api/ui/login` (JWT app **outside** the group) → `/api/admin/v2/namespaces` **200** and the admin Bearer → `/csp/fhirsql/api/ui/` **200**. Rejected: `/api/atelier/` **401** and `/api/mgmnt/v2/` **401** (`JWTAuthEnabled=0`). `POST /api/admin/refresh` with JSON `{"refresh_token":…}` → **200** new pair, same `sid`; the refresh token sent as a Bearer header instead → **401**. `POST /api/admin/logout` (Bearer) → **200**; afterwards the access token → 401 and the refresh token → 401. `POST /api/admin/revoke` `{"refresh_token"}` → **200**; refresh afterwards → 401. Wrong password → 401. Tampered signature → 401. Empty-body login with no cookies → 401. Repeated in Chrome (clean-jwt): login 200, refresh 200, refreshed Bearer → namespaces 200 and interop mgmt-url 200. |
| **H3** which cookie carries the silent login | **Found: `CSPBrowserId`** | The classic login POST to `/csp/sys/%25CSP.Portal.Home.zen` (302) sets three cookies: `CSPSESSIONID-SP-52774-UP-csp-sys-` (`path=/csp/sys/`), **`CSPBrowserId=…; path=/; httpOnly; sameSite=strict`**, `CSPWSERVERID` (`path=/`). A JWT login on any JWT application sets the same `CSPBrowserId`. curl with **`CSPBrowserId` alone**: `POST /api/interop-editors/login` **200**, `POST /api/admin/login` **200**, `POST /csp/fhirsql/api/ui/login` (no group) **401**; a garbage value → 401. All classic cookies **without** `CSPBrowserId` (obtainable by logging in without the hidden `IRISSessionToken` field, which succeeds but issues no browser id): each alone, all together, all-but-one → **401** every time, on both login endpoints. Chrome's request header on every silent login was exactly `CSPWSERVERID; IRISSessionToken; CSPBrowserId` (the `/csp/sys/` session cookie is path-excluded). Ending it: classic logout `?IRISLogout=end` → the cookie no longer mints (401); `POST /api/admin/logout` with Bearer **and** cookie → no longer mints (401); `POST /api/admin/logout` with Bearer **only** → that app's `sid` is revoked but the cookie still mints (200). |
| **H4** OcuPilot-first flow | **Pass, silently, no `VSCODE=1` needed** | clean-jwt: JWT login through the spike page (sets `CSPBrowserId`), then the iframe → `POST /api/interop-editors/login` empty body **200**, editor rendered; its `sessionStorage` holds `Rule_Editor-0-accessToken`, `Rule_Editor-0-user`, `Rule_Editor-0-refreshToken`. clean-portal (classic login only): same, banner shows `RULE EDITOR account_circle _SYSTEM`. **VSCODE branch also recorded**: `?VSCODE=1` posted `{"direction":"vscode","type":"compatible"}` to the parent after 225 ms, then `{"direction":"vscode","type":"changed","dirty":false}`; the parent's `postMessage({type:"auth",username,password})` produced `POST /api/interop-editors/login` with body `{"user":"_SYSTEM","password":"SYS"}` → 200 and the editor rendered without the top banner. The password crosses into the frame and onto the wire from it. |

**Pass/fail against section 6 of the handoff.** Shared-session path: H1(b) and (c) pass from both applications, H1(a) fails from both; the carrier is `CSPBrowserId`, gated by the API application's Group by ID, not by the page's. JWT-only path: passes; **one login covers every JWT-enabled application on the instance**, in or out of the group. Embedded editors: pass with no user interaction in H1 and in H4; the `VSCODE=1` auth message works but is not required.

## 2. Observation log

Every row: context · method · URL · credentials sent · status. `default` = Chrome default context after a classic portal form login; `clean-jwt` and `clean-portal` are isolated Chrome contexts; `curl` = no browser.

| # | Context | Method and URL | Credentials | Status |
| --- | --- | --- | --- | --- |
| 1 | curl | `POST /api/admin/login` | JSON user/password | 200, tokens, `Set-Cookie: CSPBrowserId=…; path=/; httpOnly; sameSite=strict` |
| 2 | curl | `POST /api/admin/login` | none, empty body | 401 |
| 3 | curl | `GET /api/admin/info` | none | 401 |
| 4 | curl | `POST /api/interop-editors/login` | none, empty body | 401 |
| 5 | curl | `GET /api/admin/v2/namespaces`, `/api/admin/info`, `/api/interop-editors/v7/HSCUSTOM/mgmt-url`, `/api/security-config/credential/v1/credentials` | admin Bearer / interop-editors Bearer | 200 / 200 on all four |
| 6 | curl | `GET /api/atelier/`, `GET /api/mgmnt/v2/` | admin Bearer / interop-editors Bearer | 401 / 401 on both |
| 7 | curl | `POST /api/admin/refresh` | JSON `{"refresh_token"}` | 200, new pair, same `sid` |
| 8 | curl | `POST /api/admin/refresh` | refresh token as Bearer, empty body | 401 `WWW-Authenticate: Bearer` |
| 9 | curl | `POST /api/admin/logout` | access Bearer only | 200; then namespaces with that Bearer 401; refresh with that refresh token 401 |
| 10 | curl | `POST /api/admin/revoke` | Bearer + JSON `{"refresh_token"}` | 200; refresh afterwards 401 |
| 11 | curl | `POST /api/admin/login` | wrong password | 401 |
| 12 | curl | `GET /api/admin/info` | Bearer with last character altered | 401 |
| 13 | curl | `GET /csp/fhirsql/api/ui/` | none / Basic / admin Bearer | 401 / 200 / 200 |
| 14 | curl | `POST /csp/fhirsql/api/ui/login` | JSON user/password | 200, token `app="/csp/fhirsql/api/ui/"` |
| 15 | curl | `GET /api/admin/v2/namespaces`, `/api/interop-editors/v7/HSCUSTOM/mgmt-url` | fhirsql Bearer | 200 / 200 |
| 16 | curl | `GET /csp/fhir-management/api/` | none / admin Bearer | 401 / 404 (authenticated, route absent) |
| 17 | curl | `POST /api/interop-editors/login` | `Cookie: CSPBrowserId=<from 1>` only | 200, token `app="/api/interop-editors/"`, different `sid` |
| 18 | curl | `POST /api/admin/login` | same cookie only | 200 |
| 19 | curl | `POST /csp/fhirsql/api/ui/login` | same cookie only | 401 |
| 20 | curl | `GET /api/admin/info` | same cookie only | 401 |
| 21 | curl | `POST /api/interop-editors/login` | `Cookie: CSPBrowserId=AAAA…` | 401 |
| 22 | curl | `POST /api/admin/logout` then `POST /api/interop-editors/login` | Bearer only; then cookie only | 200; then **200** (cookie survives a Bearer-only logout) |
| 23 | curl | `POST /api/admin/logout` then `POST /api/interop-editors/login` | Bearer + cookie; then cookie only | 200; then **401** |
| 24 | curl | classic form login `POST /csp/sys/%25CSP.Portal.Home.zen` | `$NAMESPACE`, hidden `IRISSessionToken`, user, password, `IRISLogin=Login` | 302 to home; `Set-Cookie` csp-sys session, **`CSPBrowserId`**, `CSPWSERVERID` |
| 25 | curl | same login **without** the hidden token | user, password, `IRISLogin=1` | 200 logged in (`Welcome, _SYSTEM`), `Set-Cookie` csp-sys session, `IRISSessionToken`, `CSPWSERVERID`, **no `CSPBrowserId`** |
| 26 | curl | `POST /api/interop-editors/login` and `/api/admin/login` | cookies from 25 in every combination (each alone, all, all-but-one) | 401 on every combination |
| 27 | curl | `POST /api/interop-editors/login`, `/api/admin/login`, `/csp/fhirsql/api/ui/login` | `CSPBrowserId` from 24 only | 200 / 200 / 401 |
| 28 | curl | `GET /csp/sys/%25CSP.Portal.Home.zen?IRISLogout=end` then `POST /api/interop-editors/login` | jar from 24; then cookie only | 200; then 401 |
| 29 | default, page `/ocupilot-spike/index.html` | `GET /api/admin/info`, `GET …/v7/HSCUSTOM/mgmt-url`, `GET /api/admin/v2/namespaces` | cookies only | 401 / 401 / 401 |
| 30 | default, same page | `POST /api/interop-editors/login`, `POST /api/admin/login` | cookies only, empty body | 200 / 200 (request `Cookie: CSPWSERVERID; IRISSessionToken; CSPBrowserId`) |
| 31 | default, same page, iframe `/ui/interop/rule-editor/index.html?$NAMESPACE=HSCUSTOM` | `POST /api/interop-editors/login` (frame), `GET /api/interop-editors/info`, `…/mgmt-url` ×2, `…/%25SYS/system-mode`, `…/sourcecontrol/enabled` | cookies, then Bearer | 200 on all; toolbar rendered |
| 32 | default, page `/ocupilot-spike-nogroup/index.html` | same as 29–31 | same | same statuses; editor rendered |
| 33 | default, nogroup page, iframe `…&VSCODE=1` | parent receives `compatible` (225 ms) and `changed`; parent posts `auth` | body `{"user","password"}` | `POST /api/interop-editors/login` 200; editor rendered, no banner |
| 34 | clean-jwt, `/ocupilot-spike/index.html` | `POST /api/admin/login` JSON; then `GET /api/admin/info` cookies only; then `POST /api/interop-editors/login` empty body | | 200; 401; **200** |
| 35 | clean-jwt | `GET /api/atelier/` | cookies only | **pending forever**: 401 with `WWW-Authenticate: Basic` opens Chrome's native credential dialog and blocks the fetch |
| 36 | clean-jwt, ~7 min later | `GET /api/admin/v2/namespaces`, `…/mgmt-url` | the 60-second Bearer, expired | 401 / 401 |
| 37 | clean-jwt | `POST /api/admin/refresh` JSON; then both GETs | refreshed Bearer, same `sid` | 200; 200 / 200 |
| 38 | clean-jwt, iframe | as 31 | | 200 on all; editor rendered; frame `sessionStorage` keys `Rule_Editor-0-accessToken/-user/-refreshToken` |
| 39 | clean-portal | classic form login (browser) | hidden token present | 302; `Set-Cookie` csp-sys session, `CSPBrowserId`, `CSPWSERVERID` (headers read from the request) |
| 40 | clean-portal, `/ocupilot-spike/index.html` | `POST /api/interop-editors/login`, `POST /api/admin/login` empty body; `GET /api/admin/info` | cookies only | 200 (`sub=_SYSTEM`) / 200 / 401 |
| 41 | clean-portal, iframe | as 31 | | editor rendered, banner `RULE EDITOR account_circle _SYSTEM`, no password field |
| 42 | clean-portal, after `?IRISLogout=end` in the sibling tab | `POST /api/interop-editors/login`, `POST /api/admin/login` empty body; frame's stored Bearer → `…/mgmt-url` | | 401 / 401 / 401 (the last is consistent with either revocation or the 60-second expiry; not isolated) |

## 3. Headers that decide each verdict (trimmed)

```
# H2/H3 — JWT login sets the browser id (curl, no cookies sent)
POST /api/admin/login   {"user":"_SYSTEM","password":"SYS"}
HTTP/1.1 200 OK
SET-COOKIE: CSPBrowserId=4JLqKSsIgNT872Ragqu_HQ; path=/; httpOnly; sameSite=strict;
Content-Type: application/json
{"access_token":"…","refresh_token":"…","sub":"_SYSTEM","iat":1788880315.79,"exp":1788880375}

# H3 — classic portal login sets the same browser id (Chrome, clean-portal; curl identical)
POST /csp/sys/%25CSP.Portal.Home.zen   $NAMESPACE=HSCUSTOM&IRISSessionToken=…&IRISUsername=_SYSTEM&IRISPassword=SYS&IRISLogin=Login
HTTP/1.1 302   location: /csp/sys/%25CSP.Portal.Home.zen?$NAMESPACE=HSCUSTOM
set-cookie: CSPSESSIONID-SP-52774-UP-csp-sys-=…; path=/csp/sys/; httpOnly; sameSite=strict;
set-cookie: CSPBrowserId=SyLTTIG_wA2IV2v5bKxAoQ; path=/; httpOnly; sameSite=strict;
set-cookie: CSPWSERVERID=hA0QjnrM; path=/; httpOnly;

# H1 — the silent login as Chrome sent it (default context, page served by /ocupilot-spike)
POST /api/interop-editors/login   content-length: 0
cookie: CSPWSERVERID=hA0QjnrM; IRISSessionToken=H3FKe0PB2HFma-mH; CSPBrowserId=FNtjig4mJHwgT2l21QJHZg
HTTP/1.1 200   content-type: application/json   (no Set-Cookie)

# H2 — refresh must be a JSON body, not a Bearer
POST /api/admin/refresh   {"refresh_token":"…"}          → 200 {"access_token","refresh_token",…}
POST /api/admin/refresh   Authorization: Bearer <refresh> → 401 WWW-AUTHENTICATE: Bearer

# Atelier is the odd one out
GET /api/atelier/   Authorization: Bearer <admin>          → 401
GET /api/atelier/   (cookies only, from a page)            → 401 WWW-Authenticate: Basic → browser credential prompt
```

## 4. Decoded JWT claims

All tokens: header `{"alg":"ES256","typ":"JWT"}`. Access token payload `{iat, exp, iss, sub, sid, app}`; refresh token payload `{iat, exp, iss, sid, app}` (no `sub`). Top-level login response also carries `sub`, `iat`, `exp`.

| Minted by | `iss` | `sub` | `app` | access `exp − iat` | refresh `exp − iat` |
| --- | --- | --- | --- | --- | --- |
| `POST /api/admin/login` | `b066ba383583/IRIS` | `_SYSTEM` | `/api/admin/` | 60 s | 900 s |
| `POST /api/interop-editors/login` | same | `_SYSTEM` | `/api/interop-editors/` | 60 s | 900 s |
| `POST /csp/fhirsql/api/ui/login` | same | `_SYSTEM` | `/csp/fhirsql/api/ui/` | 60 s | 900 s |
| `POST /api/admin/refresh` | same | `_SYSTEM` | `/api/admin/` | 60 s, **same `sid`** as the pair it replaced | 900 s |

The `app` claim is **not enforced** on acceptance: every JWT-enabled application accepted every token above. `sid` is the server-side session that `logout` and `revoke` end. The 60 s and 900 s lifetimes are the `JWTAccessTokenTimeout` and `JWTRefreshTokenTimeout` of the issuing application (both 60 / 900 on every application read, including the two spike applications, so they are the defaults `Security.Applications.Create` applies).

## 5. Documentation quotations

`irisdocs/guides/GSA_manage_applications.md` (local mirror of the System Administration Guide):

- Line 793–795, **Group by ID**: "Do not use. This field is for migrated legacy applications only and documentation is available for it." (The link goes to `GCAS_apps#GCAS_apps_smpgen`, not mirrored.)
- Line 761–771, JWT: "Use JWT Authentication — (For a REST application) Whether the application supports JSON web token (JWT) authentication. JWT Access Token Timeout — The number of seconds until the JWT expires. JWT Refresh Token Timeout — The number of seconds until the refresh token for the JWT expires." Nothing about the login, refresh, logout or revoke endpoints, the request shapes, or the browser-id cookie.
- Line 861–867, **Session Cookie Path**: "The application only sends the cookie for pages within the specified scope. If you restrict the scope to pages required by a single web application, this prevents other web applications on this machine from using this session cookie … a primary application and its subapplications can have different security settings while simultaneously sharing a session cookie (if they all use the primary application's path)." This describes `CSPSESSIONID-*`, which is path-scoped and played no part; it does not describe `CSPBrowserId`, which is `path=/`.

`irissys/Security/Applications.cls` (Documatic text on the exported class, line 139–140), `GroupById`: "Indicates whether this application's authentication will move in sync with other applications in the same id group. For CSP Web Application only." This is the sentence that matches what was observed: the *API* application's group decides whether the browser id may mint a token there. The "For CSP Web Application only" qualifier is contradicted by `/api/admin` and `/api/interop-editors`, both REST applications, honouring it.

**Net:** the documentation deprecates the mechanism the vendor's own portal, Angular editors and hidden admin API rely on, and documents neither the browser-id cookie nor the JWT endpoints. The contradiction recorded in `api-coverage-r1-1.md` (Leads) stands, now with the mechanism itself observed.

## 6. The mechanism, as now established

1. **One browser-level login identity: `CSPBrowserId`** (`path=/`, `httpOnly`, `SameSite=Strict`, no `Expires`). It is issued by a classic portal login that goes through the CSRF-token path (`/csp/sys` has `CSRFToken=1`; a form POST without the hidden `IRISSessionToken` still logs in but is not issued a browser id) and by any JWT login on a JWT-enabled application.
2. **Minting:** `POST <jwt-app-root>/login` with an empty body and that cookie returns a fresh access/refresh pair for the same user, **only if the JWT application carries the same `GroupById` as the application that issued the cookie**. Out-of-group JWT applications answer 401. The classic portal, `/ui/interop`, `/api/admin`, `/api/interop-editors`, `/api/security-config`, `/csp/fhir-management/api`, the two OAuth2 API apps and `/csp/healthshare/hssys/app/api` are all in `%ISCMgtPortal`.
3. **Authorization:** only `Authorization: Bearer <access>` authorizes a data call on these applications; cookies alone never do (`UseSession=0`). Any JWT-enabled application accepts any valid, unrevoked token from this instance regardless of group or `app` claim. `/api/atelier` and `/api/mgmnt` (`JWTAuthEnabled=0`) accept only Basic or their own CSP session.
4. **Renewal:** `POST <root>/refresh` with JSON `{"refresh_token"}` returns a new pair under the same `sid`. The vendor bundles do this at `exp − iat` minus a cushion, and on any 401 they refresh and retry once (`refreshTokens()` in `ui/interop/rule-editor/main.*.js`).
5. **Ending:** `POST <root>/logout` (null body, Bearer) ends that `sid`; when the browser-id cookie accompanies it, the browser-level login ends as well, so every in-group application stops minting. `POST <root>/revoke` (the bundles' `timeout()` path) ends the `sid` only. The classic `?IRISLogout=end` ends the browser-level login too.
6. **The embedded editors need nothing from the host.** Loaded same-origin in an iframe, they call `doLogin()` with no arguments, mint from the cookie, keep their tokens in the frame's `sessionStorage`, and render. This works whether the browser id came from the classic portal or from OcuPilot's own JWT login.

## 7. Recommended web-application settings

| Setting | `/ocupilot` — static Angular shell | `/api/ocupilot` — OcuPilot's own REST (only if custom endpoints are needed; D4 lists them) | Rationale from the evidence |
| --- | --- | --- | --- |
| Type | CSP application, `ServeFiles=1`, `Path` = the built bundle directory | REST, `DispatchClass` = the `%CSP.REST` subclass | as `/ui/interop` and `/api/admin` |
| `NameSpace` | `HSCUSTOM` if present, else `USER` | same | project rule |
| `AutheEnabled` | **64** (unauthenticated static files, exactly like `/ui/interop`); the SPA performs the login itself | **32** (password) | rows 24, 34: the shell needs no CSP session; the REST app must be password-capable for `POST /login` |
| `JWTAuthEnabled` | n/a | **1** | rows 5, 15: Bearer is the only thing that authorizes |
| `JWTAccessTokenTimeout` / `JWTRefreshTokenTimeout` | n/a | 60 / 900 to match the vendor, or raise the access timeout to 300 to cut refresh traffic; note the shell will mostly carry `/api/admin`-minted tokens, whose lifetimes are `/api/admin`'s | section 4 |
| `GroupById` | **not needed** (H1-control); harmless if set | **`%ISCMgtPortal`** if the shell should be able to mint from it silently and if its tokens should be minted from a classic portal session; omit it for Design B | rows 17–19, 27 |
| `UseSession` (dispatch class parameter) | n/a | **0** | `/api/admin`, `/api/interop-editors` |
| `CookiePath`, `SessionScope` | defaults (`/ocupilot/`, Strict) | defaults | `CSPSESSIONID-*` plays no role; `CSPBrowserId` is `path=/` regardless |
| `CSRFToken` | 0 | 0 | protects CSP login forms only |

**What the Angular shell does.**

- **Startup:** `POST /api/admin/login` with an empty body and `credentials: "include"`. 200 → the user is logged in (portal-first case, or a returning tab); store the pair. 401 → show OcuPilot's login form and `POST /api/admin/login` with `{"user","password"}` (OcuPilot-first case). Either way the response sets or refreshes `CSPBrowserId`.
- **Where the token lives:** `sessionStorage` (per tab, as the vendor does), never `localStorage`; the shell adds `Authorization: Bearer` to every call to `/api/admin`, `/api/interop-editors`, `/api/security-config` and `/api/ocupilot`. One token serves all of them.
- **Refresh:** schedule `POST /api/admin/refresh` `{"refresh_token"}` at `exp − iat − 10 s`; on any 401, refresh once and retry; if the refresh fails, return to the login form.
- **Logout:** `POST /api/admin/logout` with the Bearer **and** `credentials: "include"`, then clear `sessionStorage`. This ends the browser-level login too, so the classic portal and the embedded editors are logged out as well (row 23).
- **Atelier (`/api/atelier`):** the token is not accepted, and a cookie-only call from the page triggers the browser's native Basic-auth prompt (row 35). Never call it without an explicit `Authorization: Basic` header, or route Atelier-backed features through `/api/ocupilot`. Lead: `Security.Applications` could enable JWT on `/api/atelier` by configuration; not tested here because it changes a vendor application.
- **Embedded editors:** iframe `/ui/interop/<editor>/index.html?$NAMESPACE=…&rule|DTL|BP=…` in normal mode; they log in silently after either login path. Use `VSCODE=1` only where the host needs the `saved` / `compiled` / `bad*` events, and then post the `auth` message knowing the password enters the frame (row 33). Untested alternative for the architecture: because the frame is same-origin and shares the tab's `sessionStorage`, the host could write `Rule_Editor-0-accessToken` / `-refreshToken` / `-user` before loading `?VSCODE=1`, so the editor starts authenticated without ever seeing a password.

## 8. Two viable designs

- **Design A — silent-first with Group by ID (recommended for the contest).** The shell tries the empty-body login first, so a user arriving from the classic portal is never asked to log in, and OcuPilot's own REST application joins `%ISCMgtPortal`. Trade-off: it depends on a setting the documentation deprecates, but it is exactly what the vendor's shipped portal, editors and admin API use, and the JWT-only fallback below is built in.
- **Design B — JWT-only, no Group by ID on OcuPilot's own applications.** The shell always shows its own login; `/api/ocupilot` accepts Bearers (any JWT app does) but never mints from the browser cookie. Trade-off: one extra login when the user comes from the classic portal, in exchange for not depending on Group by ID for anything OcuPilot owns; the embedded editors still log in silently because their API is in the vendor's group and OcuPilot's JWT login issued the cookie.

Both designs give: one login, one token for every API the contest needs, embedded editors with no password hand-off, and a logout that ends everything.

## 9. What was not tested, and why

- **Cookie deletion inside Chrome.** The chrome-devtools MCP has no cookie-deletion tool and the cookies are `httpOnly`; isolation was done in curl with the same cookies (rows 17–28), which is stronger evidence anyway.
- **Whether the classic logout revoked the frame's outstanding tokens** or they merely hit the 60-second expiry (row 42): both give 401; not separated.
- **Group by ID on OcuPilot's own JWT application** was not created (no ObjectScript in this spike); the inference that it would mint from `CSPBrowserId` when in the group rests on `/api/admin`, `/api/interop-editors` and the negative control `/csp/fhirsql/api/ui` (rows 17–19).
- **HTTPS, a reverse proxy, or a cross-origin dev server.** `CSPBrowserId` is `SameSite=Strict`; an `ng serve` on another port will not carry it. Local development must proxy through the IRIS origin (inference from the cookie attributes, not observed).
- **Clean-up caveat on the automation browser.** The chrome-devtools profile persists to disk and a leftover instance from the morning session held its lock; it was stopped, and the decisive runs used isolated contexts so no stale `CSPBrowserId` could contaminate them (H3 was additionally reproduced from scratch in curl).
- **Web Gateway 404 after `Security.Applications.Create()`** (handoff §4 step 4) did **not** occur: both applications served `index.html` with 200 immediately.

## 10. What the research lead should integrate

- **research.md D4, "Auth and session model":** replace "How the shipped Angular bundles obtain their JWT after portal login was not established from a primary source" with the mechanism in section 6; claim [22] is verified with the correction that cookies never authorize data calls; the community post [23] is now confirmed ("a mechanism to use the session cookie to generate the JWT token" is `CSPBrowserId` plus the empty-body `POST /login`).
- **research.md D5, mechanics and risk:** claim [25] verified; the silent login does not depend on a classic-portal session at all, only on the browser id that any in-group login issues; the `VSCODE=1` password hand-off is optional.
- **Open questions:** close "which cookie carries the silent login" (answered) and "same-origin Atelier call" (JWT not accepted; cookie-only call triggers a Basic prompt; needs explicit Basic or a custom route).
- **Catalog rows SH-01, SH-10, CP-02, PK-11, PK-12:** login and session requirement = empty-body silent login then form fallback, Bearer everywhere, JSON refresh, logout with cookie; embedded editors = normal mode, no auth hand-off; packaging = the two web-application setting rows in section 7.

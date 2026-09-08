# Packaging and deployment — round 1 — 2026-09-08

Sources consulted: 16 (13 pages read directly; 3 search-result sets whose cited pages were seen as snippets only — marked "snippet" below). Budget: 19 of 20 tool calls used. Firewall respected: no project files read; no training-data conclusions.

## IPM state of play — version line, IRIS support, install on Community images

**Version line (two sources).** The current line is **0.10.x**; **0.10.10 is in beta** (v0.10.10-beta.6, 2026-08-26; beta.5 2026-08-25; beta.4 and beta.3 2026-08-21; beta.2 2026-08-19) per the GitHub releases page. Developer Community carries InterSystems release-note posts for **0.10.8** and **0.10.7** (indexed 2026-07-13) and **0.10.6** (2026-03-09). So the latest stable is 0.10.8 or later; 0.10.10 is imminent.

**IRIS support (single source — README compatibility table).** "IPM 0.10.x: 2022.1+; IPM 0.9.x: Any; earlier versions: <2025.1". For IRIS 2026.x only 0.10.x applies. Not corroborated by a second source this run.

**Install on a Community container.** README: fetch the installer from `pm.community.intersystems.com` (`s version="latest" s r=##class(%Net.HttpRequest).%New(),r.Server="pm.community.intersystems.com" ...`) or offline `do $System.OBJ.Load("/path/to/zpm.xml","ck")`; verify with `USER>zpm` → `zpm: USER>`. Second source (docs.intersystems.com, Supply Chain install page, snippet): the full one-liner is `set r = ##class(%Net.HttpRequest).%New(),r.Server="pm.community.intersystems.com",r.SSLConfiguration="ISC.FeatureTracker.SSL.Config" d r.Get("/packages/zpm/0.9.0/installer"),$system.OBJ.LoadStream(r.HttpResponse.Data,"c")` (replace `0.9.0` with `latest`).

**Do `intersystemsdc/*` images ship IPM preinstalled?** Evidence is mixed and partly stale:
- IPM wiki "04. Docker Images" only lists 2020-era `-zpm` tags with ZPM 0.2.10 preinstalled (e.g. `intersystemsdc/iris-community:2020.4.0.524.0-zpm`). It is not current.
- The `iris-fullstack-template` Dockerfile uses `FROM intersystemsdc/iris-community` and its `iris.script` calls `zpm "load ..."` with no install step — implying IPM was preinstalled in that image at the time.
- The **current** `iris-dev-template` Dockerfile (module v2.0.10) "downloads ZPM installer via wget to /tmp/zpm.xml" during the build — i.e. the canonical template does **not** rely on a preinstalled IPM. Safest reading: install IPM explicitly in the Dockerfile; it is idempotent on images that already have it. **Unverified:** whether `intersystemsdc/iris-community:latest` today carries IPM.

**Breaking changes relevant to module.xml / packaging.**
- 0.9.0 (Dec 2024): "IPM is no longer mapped across namespaces"; restore legacy behaviour with `zpm "enable -map -globally"` (README). Consequence: `zpm` is only available in namespaces where it was installed/mapped. 0.10.10-beta.4 "fixed a crash scenario in shell operations when target namespaces lacked IPM mappings" (releases page).
- `<CSPApplication>` "has been deprecated in IPM 0.9.0 and later; use WebApplication instead" (wiki 03). Both InterSystems community templates still use `CSPApplication` — copy their attributes, not the element.
- `${dbrole}` deprecated → `${globalsDbRole}` (wiki 03). Templates still use `${dbrole}`.
- `${ipmdir}` available from 0.10.5+; `<UpdatePackage>` from 0.10.4+ (wiki 03).
- 0.10.10-beta.3: "Added system requirement settings for the %SYS namespace" (releases page; meaning not elaborated).
- 0.10.10-beta.6: fixed sync "path normalization when SourcesRoot is '.'" (releases page).

**Load from local folder.** `zpm "load /home/irisowner/irisbuild/ -v":1:1` after `zn "IRISAPP"` (fullstack `iris.script`). Wiki has an "Installation Patterns" page (not read).

**Publishing.** README defers to Developer Community articles; wiki has "Publishing a Release" (not read). The docs snippet shows registry login as `repo -n registry -r -url https://pm.intersystems.com/ -token YOUR_IPM_TOKEN` (that is InterSystems' private registry, not the community one). 0.10.7 added ORAS/OCI registry support incl. GHCR authentication (DC release notes, snippet) — an alternative distribution channel.

## module.xml elements that matter

| element | attributes/settings | what it does | source URL |
|---|---|---|---|
| `<Name>`, `<Version>`, `<Packaging>module</Packaging>`, `<Description>`, `<Keywords>` | Version = semver (`1.0.0`, `1.0.0-alpha.1`) | identity | https://github.com/intersystems/ipm/wiki/03.-IPM-Manifest-(module.xml) |
| `<SourcesRoot>` | text, e.g. `src` | required; root for resource directories | wiki 03 |
| `<Dependencies><ModuleReference><Name/><Version/>` | ranges `^2.2.1`, `>=1.0.0 && <3.0.0`, `*` | declares deps | wiki 03 |
| `<SystemRequirements>` | `Version=">=2020.1"`, `Interoperability="enabled"`, `Health="1"`, `IPMVersion=">=0.10.3"`, `PythonVersion=">=3.12.0"` | gate install on platform | wiki 03 |
| `<Default Name="count" Value="7"/>` | overridable at install: `zpm "install demo-module -Dcount=12"` | parameters | wiki 03 |
| `<Resource>` | `Name` (suffix `.PKG .CLS .INC .MAC .LOC .GBL .DFI .LUT .X12 .ESD .HL7 .DTL .BPL`), `Directory`, `Deploy`, `Flags`, `Generated`, `Preload`, `ProcessorClass`, `Scope` | code/data to load; example `<Resource Directory="cls" Name="Demo.PKG"/>` (fullstack template) | wiki 03; fullstack module.xml |
| `<FileCopy>` | `Name`, `Target` (aliases `InstallDirectory`, `Dest`), `Overlay`, `Defer`, `CSPApplication` | copies files/dirs at install; e.g. `<FileCopy Name="lib/" Target="${libdir}my-lib/"/>`, `<FileCopy Name="data/" Target="${ipmdir}data/"/>` (→ `/usr/irissys/ipm/<pkg>/<ver>/data/` in Docker) | wiki 03; DC IPM tag page (snippet, 2025-12-27) |
| `<WebApplication>` (recommended) | `Name="/restdemo"`, `NameSpace="${namespace}"`, `Path="/src"`, `Recurse="1"`, `MatchRoles=":${dbrole}:%SQL:%All"`, `DispatchClass="REST.Dispatch"`, `ServeFiles="1"`, `CookiePath="/restdemo"`, `UseCookies="2"`; WSGI: `Url`, `WSGIAppLocation`, `WSGIAppName`, `WSGICallable`, `DispatchClass="%SYS.Python.WSGI"` | creates the web app in Security.Applications | wiki 03 |
| `<CSPApplication>` (deprecated 0.9.0+) | `Url`, `Path`/`SourcePath`, `Directory`/`DeployPath`, `ServeFiles`, `ServeFilesTimeout`, `Recurse`, `CookiePath`, `UseCookies`/`UseSessionCookie`, `MatchRoles`, `PasswordAuthEnabled`, `UnauthenticatedEnabled`, `DefaultTimeout`, `DispatchClass` | legacy form; still what both templates ship | wiki 03; fullstack module.xml |
| `<Invoke>` | `Class`, `Method`, `Phase`, `When` (`Before`/`After`), `CheckStatus`, `CustomPhase`; child `<Arg>` | run ObjectScript at a lifecycle point; e.g. `<Invoke Class="%SYSTEM.CSP" Method="LoadPageDir" CheckStatus="true"><Arg>/my-app</Arg><Arg>ck</Arg></Invoke>` | wiki 03; DC "CSP Security - Static Files + Redirect" (snippet, 2021-11-17) |
| `<CPF Name="config.cpf" Phase="Initialize" When="Before"/>` | — | CPF merge from a module | wiki 03 |
| `<Mappings><Mapping Name="MyLib.PKG" Source="MYDB"/>` | — | package/global mappings | wiki 03 |
| `<UnitTest Name="/tests" Package="..." Phase="test"/>` | `Phase` test/verify | tests via `zpm "test module"` | wiki 03; both templates |
| `<AfterInstallMessage>` | text | post-install banner | wiki 03 |
| Expressions | `${namespace}`, `${cspdir}`, `${libdir}`, `${bindir}`, `${mgrdir}`, `${installDir}`, `${dataDir}`, `${dbrole}` (deprecated → `${globalsDbRole}`), `${namespaceRoutineDB}`, `${ipmdir}` (0.10.5+), `#{expr}` arbitrary ObjectScript | substitution anywhere in module.xml | wiki 03 |

Not found on the wiki extract: attributes named `CSRF`, `Resource` (security resource), `AutoCompile`, `Directory` on `WebApplication`; the complete lifecycle-phase list (only `Compile`, `Initialize`, `test`, `verify` appeared). See Gaps.

## Angular-from-IRIS serving patterns

**(a) Static SPA web app + separate REST web app — InterSystems' fullstack template** (`intersystems-community/iris-fullstack-template`, module `demo-coffeemaker` 1.0.2, keywords `REST,Full-stack,angular`), verbatim:

```xml
<CSPApplication CookiePath="/csp/coffee/" DefaultTimeout="900" DeployPath="${cspdir}/coffee" MatchRoles=":${dbrole}" PasswordAuthEnabled="0" Recurse="1" ServeFiles="1" ServeFilesTimeout="3600" SourcePath="/web" UnauthenticatedEnabled="0" Url="/csp/coffee" UseSessionCookie="2"/>
<SourcesRoot>src</SourcesRoot>
<Resource Directory="cls" Name="Demo.PKG"/>
<Resource Name="Demo.coffeemakerD.GBL"/>
<CSPApplication CookiePath="/rest/coffeemakerapp/" DefaultTimeout="900" DispatchClass="Demo.CoffeeMakerRESTServer" MatchRoles=":${dbrole}" PasswordAuthEnabled="1" Recurse="1" ServeFiles="1" ServeFilesTimeout="3600" UnauthenticatedEnabled="0" Url="/rest/coffeemakerapp" UseSessionCookie="2"/>
```
Pattern: the SPA build lives in repo folder `/web`, is deployed to `${cspdir}/coffee`, served by `ServeFiles="1"`; REST is a second app with `DispatchClass` and password auth. Note the two apps have **different `CookiePath`s**, so they do not share a session in this template. `MatchRoles=":${dbrole}"` grants the DB role on login.

**2026 pattern (WebApplication + FileCopy)** — `iris-class-explorer` by Evgeny Shvarov (Open Exchange, published 2026-04-02, updated 2026-04-04, v1.0.4; repo https://github.com/evshvarov/iris-class-explorer): a Vite/React front end "adapted to work as an IPM-installable IRIS web module"; "`module.xml` uses `WebApplication` and `FileCopy` so the bundle is installed as an IRIS web app"; app served at `/iris-table-stats-ui/`, "configured to run under a non-root base path"; router "handles both `/iris-table-stats-ui/` and `/iris-table-stats-ui/index.html`"; backend API at `/iris-table-stats/api` (separate app); "`docker compose build` builds the frontend first, then copies `dist/` into the IRIS image; IPM creates the IRIS web application and deploys the compiled frontend files into the CSP directory". Repo includes `codex-ipm-frontend-module-runbook.md` described as a reusable agent workflow for doing this to another front end. Verbatim module.xml not visible on the OE page (Gap).

**(b) Deep-link fallback for client-side routes** — DC post "Web application with dispatch class (%CSP.REST) also serving static files" (snippet; original 2017-01-11 with a later update explicitly for "a built Angular application using PathLocationStrategy"):

```objectscript
XData UrlMap [ XMLNamespace = "http://www.intersystems.com/urlmap" ]
{
<Routes>
<Route Url="/(.*)" Method="GET" Call="ServeStaticFile" />
</Routes>
}
ClassMethod ServeStaticFile(pPath As %String) As %Status
{
#dim %request As %CSP.Request
If '$Match(pPath,"^(assets/.*|.*\.(js|map|html|css|woff|woff2))$") {
    Set pPath = "index.html"
}
Do %request.Set("FILE",%request.Application_pPath)
Quit ##class(%CSP.StreamServer).Page()
}
```
Caveat from the same post: the Portal UI disables "CSP Files Physical Path" once a dispatch class is set, "but will save it if you add the physical path first" — so the web app needs both a physical path and a `DispatchClass` (IPM sets both from module.xml).

Alternative (DC "CSP Security - Static Files + Redirect", 2021-11-17, snippet): rename `index.html` → `index.csp`, set `angular.json` `architect.build.options.index` to `src/index.csp`, set web app `AutoCompile=1` and `ServeFiles=3`, and compile once from module.xml via `<Invoke Class="%SYSTEM.CSP" Method="LoadPageDir" CheckStatus="true"><Arg>/my-app</Arg><Arg>ck</Arg></Invoke>`. This does not by itself give deep-link fallback.

**(c) Base href.** DC thread "How are you guys developing with Angular right now?" (2019-04-09, snippet): `ng build --base-href=/webapp_name/index.html` makes `polyfills.js` etc. resolve without hand edits; older advice `--base-href=/csp/my_app/index.csp`. iris-class-explorer confirms the non-root base path approach in 2026.

**(d) Cache headers.** Only finding (same 2019 thread): set "Serve Files" to "Always" during development "to avoid CSP Gateway Cache (it sometimes serves old cached files even if files in CSP-folder already have been updated)". Nothing retrieved on explicit cache-control headers (Gap).

**(e) Auth / session sharing.** DC 2017 post comment (snippet): "one Web Application for serving CSP pages and static files and another for the REST calls ... `/csp/myapp` and `/csp/myapp/rest` ... both with the same Group ID, with session cookie and set the `UseSession` parameter on the Dispatcher class." Docs `GREST_csprest` (2026-08-30, snippet): `UseSession` "controls whether each REST call is executed under its own web session or shares a single session with other REST calls." The fullstack template instead uses password auth on REST and distinct cookie paths.

**(f) CSRF.** Nothing retrieved (Gap).

## Docker self-install patterns

**Both InterSystems templates install at image build time, not at container start.** `iris-fullstack-template` Dockerfile (verbatim core; base-image ARGs are 2019–2020 era):

```dockerfile
ARG IMAGE=intersystemsdc/iris-community
FROM $IMAGE
WORKDIR /home/irisowner/irisbuild
USER root
RUN apt update && apt-get -y install git
USER ${ISC_PACKAGE_MGRUSER}
ARG TESTS=0
ARG MODULE="demo-coffeemaker"
ARG NAMESPACE="COFFEE"
RUN --mount=type=bind,src=.,dst=. \
    iris start IRIS && \
    iris session IRIS < iris.script && \
    ([ $TESTS -eq 0 ] || iris session iris -U $NAMESPACE "##class(%ZPM.PackageManager).Shell(\"test $MODULE -v -only\",1,1)") && \
    iris stop IRIS quietly
```

`iris.script` (verbatim):
```
// Unexpire passwords to simplify dev mode. Comment these two lines for Production use
zn "%SYS"
Do ##class(Security.Users).UnExpireUserPasswords("*")
// create IRISAPP namespace
do $SYSTEM.OBJ.Load("/home/irisowner/irisbuild/Installer.cls", "ck")
set sc = ##class(App.Installer).setup()
// load all the code of the project as a ZPM package
zn "IRISAPP"
zpm "load /home/irisowner/irisbuild/ -v":1:1
halt
```
Namespace creation is done by an `App.Installer` class (`%Installer` manifest), not by IPM.

**Current `iris-dev-template` Dockerfile (master, 2026; fetched as summary, not verbatim):** `WORKDIR /home/irisowner/dev`; `ENV IRISUSERNAME "_SYSTEM"`, `IRISPASSWORD "SYS"`, `IRISNAMESPACE $NAMESPACE`; `ARG TESTS=0`, `MODULE="dc-sample"`, `NAMESPACE="IRISAPP"`; copies `.iris_init`; **downloads the ZPM installer via wget to `/tmp/zpm.xml`**; creates `/data/IRISAPP_DATA/` subdirectories; runs `iris merge iris ./merge.cpf` before `iris.script`; conditional test run; `iris stop`. So the 2026 canonical pattern = CPF merge (`iris merge`) + `iris.script` + explicit IPM install, all inside `RUN`.

**Expired passwords.** Handled by `##class(Security.Users).UnExpireUserPasswords("*")` in `%SYS` inside `iris.script` (fullstack). The dev-template's `merge.cpf` content was not read; whether it uses `PasswordHash` is unverified.

**Not retrieved this run:** `ISC_CPF_MERGE_FILE`, `-a` after-install argument, `%ZSTART`, durable `%SYS`/`ISC_DATA_DIRECTORY` interaction with a baked-in install, `HEALTHCHECK` lines. See Gaps. Note for the decision: a build-time install is invisible to durable-%SYS wipes only if the code lives in the image's databases; with `ISC_DATA_DIRECTORY` the databases move to the durable volume — the interaction is a known concern but was not evidenced this run (unverified belief).

**Bundle build.** iris-class-explorer builds the front end in a first compose/Docker stage and copies `dist/` into the IRIS image. For the **IPM registry path** the package archive itself must contain the built `dist/` (IPM `FileCopy`/`WebApplication` copy files from the package), so the built bundle must be committed or produced before `zpm "package"` — inference from the two sources, not stated verbatim.

## The two videos

| URL | title | author | date | what it teaches | docs it points to |
|---|---|---|---|---|---|
| https://www.youtube.com/watch?v=NVEOe-F5O80 | "How to Build, Test and Publish ZPM Package with REST Application for InterSystems IRIS" | InterSystems Developers (https://www.youtube.com/@InterSystemsDevelopers) | not retrievable (watch page returned only footer; oEmbed carries no date) | From the title only: building, testing (`zpm "test"`) and publishing a ZPM package that ships a REST application — the `iris-fullstack-template`/`rest-api-contest-template` workflow. Transcript/description not retrievable. | none retrievable |
| https://www.youtube.com/watch?v=havPyPbUj1I | "Package First Development Approach with InterSystems IRIS and ZPM" | InterSystems Developers | not retrievable | From the title only: authoring module.xml first and developing inside a package (load → edit → reload). | none retrievable |

Both titles say "ZPM", the pre-rename name; the current manifest reference is the IPM wiki page 03 (above), which supersedes any `CSPApplication` syntax shown in the videos (deprecated in 0.9.0).

## Namespace targeting

- IPM installs into the **namespace the shell is running in**: the template does `zn "IRISAPP"` then `zpm "load ..."`. `${namespace}` in module.xml resolves to that namespace and `WebApplication NameSpace="${namespace}"` binds the web app to it (wiki 03).
- Namespace **creation** is outside IPM in the templates (`App.Installer.setup()` via `%Installer`, loaded from `Installer.cls` in `iris.script`).
- "HSCUSTOM if present else USER" therefore belongs in `iris.script` (or an installer classmethod it calls): test existence, `zn` to the winner, then `zpm "load"`. No evidence of IPM-native conditional namespace selection (Gap). `#{expr}` (arbitrary ObjectScript in module.xml) exists but the namespace is already fixed by the time the manifest is evaluated.
- Since 0.9.0 IPM is per-namespace: on a Community image `zpm` may exist only in `USER`; either install IPM in the target namespace or `zpm "enable -map -globally"` (README). 0.10.10-beta.4 fixed a shell crash when the target namespace lacked IPM mappings.
- For registry installs the end user chooses the namespace by running `zpm` there — no packaging control.

## Pitfalls

| pitfall | reported where | date | fixed since? | mitigation |
|---|---|---|---|---|
| `CSPApplication` deprecated; templates still use it | IPM wiki 03; fullstack module.xml | wiki current; deprecation at 0.9.0 | n/a (deliberate) | write `<WebApplication>`; copy attribute values from the template |
| IPM no longer mapped across namespaces → `zpm` missing in target namespace | IPM README | 0.9.0, Dec 2024 | design change, not a bug; shell crash fixed 0.10.10-beta.4 | install IPM in HSCUSTOM/USER or `zpm "enable -map -globally"` |
| `${dbrole}` deprecated | wiki 03 | current | — | use `${globalsDbRole}` |
| Web Gateway serves stale static files | DC Angular thread (snippet) | 2019-04-09 | unknown | ServeFiles=Always in dev; consider versioned asset filenames (Angular default hashes) |
| Deep links 404 on a ServeFiles-only app | DC %CSP.REST static-files post (snippet) | 2017 + later Angular update | inherent | catch-all `Route Url="/(.*)"` → `%CSP.StreamServer.Page()` with index.html rewrite (above) |
| Portal hides "CSP Files Physical Path" once DispatchClass is set | same DC post | 2017 | unknown | set path first, or let IPM set both |
| SPA must answer both `/app/` and `/app/index.html` | iris-class-explorer README | 2026-04 | — | router handles both paths |
| Build-time templates call `%ZPM.PackageManager` (old class name) | fullstack Dockerfile | 2020-era | class family renamed in IPM (unverified) | use `zpm "test ..."` via `iris session` instead of the class name |
| IPM wiki Docker page lists only 2020 images | wiki 04 | stale | — | do not rely on `-zpm` tags; install IPM explicitly in the Dockerfile as dev-template does |
| Expired `_SYSTEM` password on Community images | fullstack iris.script comment | ongoing | no | `UnExpireUserPasswords("*")` in `%SYS` during build (dev only) |
| SourcesRoot="." path normalization bug in `sync` | IPM releases | fixed 0.10.10-beta.6 (2026-08-26) | yes, in beta | use `<SourcesRoot>src</SourcesRoot>` |
| 0.10.x requires IRIS 2022.1+ | IPM README | current | n/a | irrelevant for 2026.x targets |

## Findings

- **Claim:** IPM's current release line is 0.10.x; v0.10.10-beta.6 was published 2026-08-26 and 0.10.8/0.10.7/0.10.6 have InterSystems release-note posts. | **Source:** https://github.com/intersystems/ipm/releases ; https://community.intersystems.com/post/ipm-version-0-10-8-release-notes | **Publisher:** InterSystems (GitHub) / InterSystems Developer Community | **Pub date:** 2026-08-26 / 2026-07-13 | **Accessed:** 2026-09-08 | **Confidence:** high | **Class:** packaging
- **Claim:** IPM 0.10.x supports IRIS 2022.1+; 0.9.x supports any version. | **Source:** https://raw.githubusercontent.com/intersystems/ipm/main/README.md | **Publisher:** InterSystems | **Pub date:** current main | **Accessed:** 2026-09-08 | **Confidence:** medium (single source) | **Class:** packaging
- **Claim:** Since 0.9.0 (Dec 2024) IPM is not mapped across namespaces; `zpm "enable -map -globally"` restores the legacy behaviour. | **Source:** https://raw.githubusercontent.com/intersystems/ipm/main/README.md | **Publisher:** InterSystems | **Pub date:** Dec 2024 note | **Accessed:** 2026-09-08 | **Confidence:** high | **Class:** packaging
- **Claim:** `<CSPApplication>` is deprecated from IPM 0.9.0; `<WebApplication Name NameSpace Path Recurse MatchRoles DispatchClass ServeFiles CookiePath UseCookies>` is the recommended element. | **Source:** https://github.com/intersystems/ipm/wiki/03.-IPM-Manifest-(module.xml) | **Publisher:** InterSystems | **Pub date:** current wiki | **Accessed:** 2026-09-08 | **Confidence:** high | **Class:** packaging
- **Claim:** `<FileCopy Name Target Overlay Defer CSPApplication>`, `<Invoke Class Method Phase When CheckStatus CustomPhase>`, `<SystemRequirements Version Interoperability Health IPMVersion PythonVersion>`, `<Default Name Value>` (`-Dname=value` at install), and expressions `${namespace} ${cspdir} ${libdir} ${mgrdir} ${installDir} ${dataDir} ${globalsDbRole} ${ipmdir} #{expr}` are the module.xml surface. | **Source:** same wiki 03 | **Publisher:** InterSystems | **Pub date:** current | **Accessed:** 2026-09-08 | **Confidence:** high | **Class:** packaging
- **Claim:** InterSystems' fullstack template ships an Angular SPA and a REST API as two `CSPApplication`s with `ServeFiles="1"`, `DeployPath="${cspdir}/coffee"`, `SourcePath="/web"`, and password auth only on the REST app. | **Source:** https://raw.githubusercontent.com/intersystems-community/iris-fullstack-template/master/module.xml | **Publisher:** InterSystems Community | **Pub date:** v1.0.2 (undated) | **Accessed:** 2026-09-08 | **Confidence:** high | **Class:** packaging
- **Claim:** The 2026 pattern for a bundled SPA is `WebApplication` + `FileCopy` of a `dist/` build, non-root base path, router accepting both `/app/` and `/app/index.html`, front end built in a first Docker stage. | **Source:** https://openexchange.intersystems.com/package/iris-class-explorer | **Publisher:** Evgeny Shvarov (InterSystems) on Open Exchange | **Pub date:** 2026-04-02 | **Accessed:** 2026-09-08 | **Confidence:** medium (module.xml not seen verbatim) | **Class:** packaging
- **Claim:** Deep-link fallback is done by a `%CSP.REST` dispatcher with `<Route Url="/(.*)" Method="GET" Call="ServeStaticFile"/>` that rewrites non-asset paths to `index.html` and returns `##class(%CSP.StreamServer).Page()`. | **Source:** https://community.intersystems.com/post/web-application-dispatch-class-csp-rest-also-serving-static-files | **Publisher:** InterSystems Developer Community | **Pub date:** 2017-01-11 (+ later Angular update) | **Accessed:** 2026-09-08 (snippet via search) | **Confidence:** medium | **Class:** packaging
- **Claim:** Templates install at image build time via `RUN --mount=type=bind ... iris start IRIS && iris session IRIS < iris.script && iris stop IRIS quietly`; `iris.script` unexpires passwords in `%SYS`, creates the namespace via `%Installer`, then `zn` + `zpm "load <dir> -v":1:1`. | **Source:** https://raw.githubusercontent.com/intersystems-community/iris-fullstack-template/master/Dockerfile ; .../iris.script | **Publisher:** InterSystems Community | **Pub date:** 2020-era base tags | **Accessed:** 2026-09-08 | **Confidence:** high | **Class:** packaging
- **Claim:** The current dev-template additionally runs `iris merge iris ./merge.cpf` and downloads the IPM installer (`/tmp/zpm.xml`) itself rather than relying on a preinstalled IPM. | **Source:** https://raw.githubusercontent.com/intersystems-community/iris-dev-template/master/Dockerfile | **Publisher:** InterSystems Community | **Pub date:** master (module 2.0.10) | **Accessed:** 2026-09-08 | **Confidence:** medium (summary, not verbatim) | **Class:** packaging
- **Claim:** The two cited videos are InterSystems Developers channel videos titled "How to Build, Test and Publish ZPM Package with REST Application for InterSystems IRIS" and "Package First Development Approach with InterSystems IRIS and ZPM". | **Source:** https://www.youtube.com/oembed?url=https://www.youtube.com/watch?v=NVEOe-F5O80&format=json ; ...havPyPbUj1I | **Publisher:** YouTube/InterSystems Developers | **Pub date:** not retrievable | **Accessed:** 2026-09-08 | **Confidence:** high (title/author), none (date/content) | **Class:** packaging

## Leads

- IPM class family naming: templates call `%ZPM.PackageManager`; whether that still resolves on 0.10.x (vs `%IPM.*`) needs a live check on the ocupilot container.
- 0.10.7 ORAS/GHCR registry support: an alternative to pm.community for distribution or CI.
- `<CPF Name=... Phase="Initialize">` in module.xml and `iris merge` in the dev-template: a module can carry its own CPF merge — possibly usable for web-app or security settings.
- `FileCopy` has a `CSPApplication` attribute (undocumented in the extract) — may tie copied files to a web app's physical path; read `%IPM.ResourceProcessor.FileCopy` source.
- 0.10.10-beta.3 "system requirement settings for the %SYS namespace" — may matter if any install step needs %SYS.
- Contradiction: wiki 04 says DC images ship IPM (2020 tags); the 2026 dev-template installs IPM itself. Resolve by inspecting `intersystemsdc/iris-community:latest` on the machine (`zpm` present?).
- `UseSessionCookie="2"`/`UseCookies="2"` values appear in both templates — meaning ("2" = autodetect?) not evidenced; check Security.Applications docs.
- `PasswordAuthEnabled="0"` and `UnauthenticatedEnabled="0"` together on the template's SPA app — which auth then applies is unclear; verify against Security.Applications behaviour.

## Gaps

- Video publish dates, descriptions, transcripts: YouTube watch pages returned only footer HTML; oEmbed has no date.
- `ISC_CPF_MERGE_FILE`, `-a` after-install, `%ZSTART`, durable `%SYS` (`ISC_DATA_DIRECTORY`) interaction with baked-in installs, `HEALTHCHECK` — not retrieved.
- `merge.cpf` and `iris.script` contents of the current dev-template (only the Dockerfile summary was obtained).
- Verbatim module.xml of iris-class-explorer and its runbook.
- CSRF handling and cache-control headers for ServeFiles apps.
- Exact steps/commands to publish to pm.community.intersystems.com (wiki "Publishing a Release" not read).
- Full `zpm "load"` flag list and the "Installation Patterns" wiki page.
- Complete lifecycle-phase list for `<Invoke Phase=...>`.
- IPM GitHub issue tracker: the pitfalls search returned no relevant WebApplication/FileCopy/ServeFiles issues in the last year — either none exist or the query missed them.
- Whether IPM offers any native conditional namespace logic (none found).
- Second source for "0.10.x requires 2022.1+".

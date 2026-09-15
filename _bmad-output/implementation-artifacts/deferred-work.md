# Deferred Work Ledger

See _bmad/custom/skill-rules.md Rule 15 (entry grammar) and Rule 17 (the drain).

### DW-1: Silent probe or form login runs while install is still running
- source: epics-review-findings.json | severity: med | fix-risk: low | footprint: in-story
- evidence: Judge's first load reads as bad credentials rather than install in progress [epics-review edge-case-hunter E1; epics.md:1095-1104 @8981cdf]
- 2026-09-09T15:10:47Z status=routed owner=1-6-silent-first-sign-in by=load note=edge-case-hunter lens, pre-planning route; address in Tasks & Acceptance or decline under Design Notes. guard: AC: a login against a not-yet-installed API renders the 'installing' state, never a sign-in failure
- 2026-09-12T05:47:18Z status=resolved-by:1-6-silent-first-sign-in by=adjudication note=client half delivered: the installing state and its INSTALL.* classifier with a negative pinning test. The unwired positive half is DW-101, owned by 1.8 and planned in its epic block

### DW-2: Install fails; readiness reports only installed, version and running
- source: epics-review-findings.json | severity: med | fix-risk: low | footprint: in-story
- evidence: A failed install is indistinguishable from an install that never started [epics-review edge-case-hunter E2; epics.md:1448-1451 @8981cdf]
- 2026-09-09T15:10:47Z status=routed owner=1-17-the-smoke-script-the-readiness-endpoint-and-ci by=load note=edge-case-hunter lens, pre-planning route; address in Tasks & Acceptance or decline under Design Notes. guard: AC: readiness carries a fourth state 'install failed' with the failing step
- 2026-09-13T15:59:59Z status=resolved-by:1-17-the-smoke-script-the-readiness-endpoint-and-ci by=adjudication note=readiness carries failed as its own state, pinned by Test.Readiness.TestFailedIsItsOwnStateAndNamesNoStep (7/7 green, lead-verified). The guard's failing step is deliberately NOT reported: AD-45 forbids instance detail on the unauthenticated endpoint, so the state is distinguishable without naming the step

### DW-3: Container restarts and upgrades OcuPilot while a browser holds the old bundle
- source: epics-review-findings.json | severity: med | fix-risk: low | footprint: in-story
- evidence: Old SPA calls an upgraded API and fails in undefined ways [epics-review edge-case-hunter E4; epics.md:1074-1076 @8981cdf]
- 2026-09-09T15:10:47Z status=routed owner=1-5-the-static-shell-serves-the-spa-including-deep-links by=load note=edge-case-hunter lens, pre-planning route; address in Tasks & Acceptance or decline under Design Notes. guard: AC: the API returns its build stamp; a mismatched client is prompted to reload
- 2026-09-12T01:32:13Z status=routed owner=1-8-instance-identity-and-the-api-version-guard by=adjudication note=HALF closed: index.html no-store and hashed assets immutable are delivered and pinned by Test.Static. NOT closed: the API reporting its build stamp and the client prompting a mismatched bundle to reload
- 2026-09-12T08:27:50Z status=decision-pending owner=burndown by=spec_gate note=server half is in 1.8 (buildIdentity on the instance response). The client reload prompt needs two things this project does not have: UX copy in neither DESIGN.md nor EXPERIENCE.md, and a real build identity (Installer.cls:73 is the literal 'dev'). Owner call at the decision sheet
- 2026-09-12T09:46:32Z occurrence=1-8-instance-identity-and-the-api-version-guard
- 2026-09-13T21:00:46Z status=routed owner=15-3-about-help-shortcuts-and-the-links-panel by=merge_gate note=owner-delegated decision: charter both halves, a real build identity (Installer.cls:73 is the literal dev) and the stale-bundle reload prompt with its copy. The About panel is where build identity is displayed, so it owns the stamp and the prompt that compares against it

### DW-4: Several in-flight calls return 401 at once, each triggering its own refresh
- source: epics-review-findings.json | severity: med | fix-risk: low | footprint: in-story
- evidence: Refresh-token rotation invalidates the pair and signs the user out mid-session [epics-review edge-case-hunter E5; epics.md:1117-1121 @8981cdf]
- 2026-09-09T15:10:47Z status=routed owner=1-6-silent-first-sign-in by=load note=edge-case-hunter lens, pre-planning route; address in Tasks & Acceptance or decline under Design Notes. guard: AC: refresh is single-flight; concurrent 401s await one refresh, then retry
- 2026-09-12T05:47:18Z status=resolved-by:1-6-silent-first-sign-in by=adjudication note=single-flight refresh in api.ts/session.ts, pinned by ui/tools/api.test.mjs and session.test.mjs; a refresh kills the old access token in place, so the cascade this entry named would have logged the user out

### DW-5: Logout call fails or the instance is unreachable during sign-out
- source: epics-review-findings.json | severity: med | fix-risk: low | footprint: in-story
- evidence: Tokens remain in the tab on a shared machine after apparent sign-out [epics-review edge-case-hunter E6; epics.md:1136-1143 @8981cdf]
- 2026-09-09T15:10:48Z status=routed owner=1-7-sign-out by=load note=edge-case-hunter lens, pre-planning route; address in Tasks & Acceptance or decline under Design Notes. guard: AC: tab storage clears and the form login shows even when logout errors
- 2026-09-12T07:55:59Z status=resolved-by:1-7-sign-out by=adjudication note=made impossible by ordering rather than by a catch: the local half of sign-out runs first and unconditionally, so a failed or unreachable /logout cannot leave a usable pair. Pinned three ways in session.test.mjs and confirmed at the smoke gate - after sign-out sessionStorage held only the tab nonce

### DW-6: Tab duplication copies sessionStorage, including token pair and conversation id
- source: epics-review-findings.json | severity: med | fix-risk: low | footprint: in-story
- evidence: Two tabs silently share one token and one conversation lock [epics-review edge-case-hunter E7; epics.md:1111-1115 @8981cdf]
- 2026-09-09T15:10:48Z status=routed owner=1-6-silent-first-sign-in by=load note=edge-case-hunter lens, pre-planning route; address in Tasks & Acceptance or decline under Design Notes. guard: AC: a per-tab nonce is stamped; a duplicated tab re-authenticates and starts a new conversation
- 2026-09-12T05:47:18Z status=resolved-by:1-6-silent-first-sign-in by=adjudication note=tab-identity nonce in token-store.ts; a real duplicate tab (window.open, copied sessionStorage) discarded the copied pair and re-probed to a new sid, confirmed in the browser at the QA gate

### DW-7: User can read a namespace but not write it
- source: epics-review-findings.json | severity: med | fix-risk: low | footprint: in-story
- evidence: Read-only screens become unreachable, contradicting gated-never-hidden [epics-review edge-case-hunter E8; epics.md:1266-1268 @8981cdf]
- 2026-09-09T15:10:48Z status=routed owner=1-11-the-namespace-switch-as-data-scope by=load note=edge-case-hunter lens, pre-planning route; address in Tasks & Acceptance or decline under Design Notes. guard: AC: list every readable namespace; gate its write actions rather than hiding the namespace
- 2026-09-12T19:18:18Z status=resolved-by:1-11-the-namespace-switch-as-data-scope by=adjudication note=a readable but non-writable namespace is reported with its failed pair and still scopes reads, per the AC's read-and-write reading; the residual (the switch will not return a user to a read-only namespace) is a one-line filter change recorded in the spec

### DW-8: Route carries an ns that does not exist or the user cannot enter
- source: epics-review-findings.json | severity: med | fix-risk: low | footprint: in-story
- evidence: Deep link renders an empty or wrongly-scoped screen with no explanation [epics-review edge-case-hunter E9; epics.md:1270-1277 @8981cdf]
- 2026-09-09T15:10:48Z status=routed owner=1-11-the-namespace-switch-as-data-scope by=load note=edge-case-hunter lens, pre-planning route; address in Tasks & Acceptance or decline under Design Notes. guard: AC: an unresolvable ns renders a named error and falls back to a permitted namespace
- 2026-09-12T18:24:10Z occurrence=1-11-the-namespace-switch-as-data-scope
- 2026-09-12T19:18:18Z status=resolved-by:1-11-the-namespace-switch-as-data-scope by=adjudication note=400 NS.UNKNOWN and 403 NS.DENIED with detail.failedPair, pinned over real HTTP as a throwaway principal plus the client fallback. The review also found and fixed the canonicalisation half: names containing - or _ were excluded, so a legal namespace read as unresolvable

### DW-9: Roles or classic-page custom resources change after the startup-resolved privilege set
- source: epics-review-findings.json | severity: med | fix-risk: low | footprint: in-story
- evidence: Navigation gating disagrees with the instance until a call fails [epics-review edge-case-hunter E10; epics.md:1192-1201 @8981cdf]
- 2026-09-09T15:10:48Z status=routed owner=1-9-the-screen-descriptor-registry-and-privilege-driven-navigati by=load note=edge-case-hunter lens, pre-planning route; address in Tasks & Acceptance or decline under Design Notes. guard: AC: the privilege map re-reads on any 403 and after a permissions change event
- 2026-09-12T13:45:10Z status=resolved-by:1-9-the-screen-descriptor-registry-and-privilege-driven-navigati by=adjudication note=the server recomputes every gate per call rather than caching a startup-resolved set, and the client re-reads the map on any 403; pinned by Test.Wire against a real principal and a real $System.Security.Check

### DW-10: Instance reports no server flag, or one outside the four named
- source: epics-review-findings.json | severity: med | fix-risk: low | footprint: in-story
- evidence: Status bar and Home instance line render an empty badge [epics-review edge-case-hunter E11; epics.md:1237-1239 @8981cdf]
- 2026-09-09T15:10:48Z status=routed owner=1-10-header-status-bar-and-page-chrome by=load note=edge-case-hunter lens, pre-planning route; address in Tasks & Acceptance or decline under Design Notes. guard: AC: an unset or unrecognised flag renders a defined default badge with its word
- 2026-09-12T16:25:11Z status=resolved-by:1-10-header-status-bar-and-page-chrome by=adjudication note=closed by this story's tasks and pinned by the component runner; see the spec's Verification for the named mutation

### DW-11: Detail route or deep link loaded for an entity that no longer exists
- source: epics-review-findings.json | severity: med | fix-risk: low | footprint: in-story
- evidence: Deleted entity produces a generic error or a blank detail screen [epics-review edge-case-hunter E12; epics.md:1328-1338 @8981cdf]
- 2026-09-09T15:10:48Z status=routed owner=1-13-uniform-error-handling-and-the-connectivity-probe by=load note=edge-case-hunter lens, pre-planning route; address in Tasks & Acceptance or decline under Design Notes. guard: AC: a 404 on a detail route renders 'no longer present' with a link back to the list
- 2026-09-12T23:59:51Z status=resolved-by:1-13-uniform-error-handling-and-the-connectivity-probe by=adjudication note=closed by the failure taxonomy and its recovery paths; the review found and fixed two siblings of the same shape - a parked recovery deleted by the notification meant to drive it, and a park whose only trigger was taken by the next verdict

### DW-12: Neither HSCUSTOM nor USER exists, or the documented override names a missing namespace
- source: epics-review-findings.json | severity: med | fix-risk: low | footprint: in-story
- evidence: Install fails obscurely or lands in an unintended namespace [epics-review edge-case-hunter E13; epics.md:1424-1427 @8981cdf]
- 2026-09-09T15:10:48Z status=routed owner=1-16-the-ipm-module-generated-from-one-roster by=load note=edge-case-hunter lens, pre-planning route; address in Tasks & Acceptance or decline under Design Notes. guard: AC: install validates the target namespace exists and fails loudly naming it
- 2026-09-13T08:23:41Z status=resolved-by:1-16-the-ipm-module-generated-from-one-roster by=adjudication note=namespace validation fails naming both candidates and the documented override; the review lowered the seam to NamespaceExists so the candidate order is observed rather than replaced, which also revealed the old resolver would have installed rather than refused

### DW-13: Operator's instance already carries a real /csp/myapp application
- source: epics-review-findings.json | severity: med | fix-risk: low | footprint: in-story
- evidence: Demo enables and grants a resource on the operator's real application [epics-review edge-case-hunter E14; epics.md:1051-1054 @8981cdf]
- 2026-09-09T15:10:48Z status=routed owner=1-4-one-command-brings-up-an-instance-with-ocupilot-installed by=load note=edge-case-hunter lens, pre-planning route; address in Tasks & Acceptance or decline under Design Notes. guard: AC: the fixture path is genuinely namespaced, or install refuses on collision
- 2026-09-11T19:38:29Z status=resolved-by:1-4-one-command-brings-up-an-instance-with-ocupilot-installed by=adjudication note=CreateWebApp creates /csp/myapp only when absent and never modifies one it did not create; pinned AC10 (Verification mutation run 343); AD-25 now carries the behavioral reading (DW-74)

### DW-14: Fixture list omits the suspended task Stories 2.8 and 5.11 require
- source: epics-review-findings.json | severity: med | fix-risk: low | footprint: in-story
- evidence: UJ-6 has no data on a clean install; the Tasks demo cannot run [epics-review edge-case-hunter E15; epics.md:1051-1054 @8981cdf]
- 2026-09-09T15:10:48Z status=routed owner=1-4-one-command-brings-up-an-instance-with-ocupilot-installed by=load note=edge-case-hunter lens, pre-planning route; address in Tasks & Acceptance or decline under Design Notes. guard: AC: Story 1.4's fixture set includes a task suspended after an error
- 2026-09-11T19:38:29Z status=resolved-by:1-4-one-command-brings-up-an-instance-with-ocupilot-installed by=adjudication note=demo task fixture suspends after a real failing run; AC11 TestDemoTaskIsSuspendedAfterAnError observes it (runs 469, 502; mutation run 485) and its daily schedule (mutation run 498)

### DW-15: Clean install has no application errors for the Logs area's confirmed write
- source: epics-review-findings.json | severity: med | fix-risk: low | footprint: in-story
- evidence: One-confirmed-write-per-area is unreproducible on the judge's own path [epics-review edge-case-hunter E16; epics.md:1051-1054 @8981cdf]
- 2026-09-09T15:10:48Z status=routed owner=1-4-one-command-brings-up-an-instance-with-ocupilot-installed by=load note=edge-case-hunter lens, pre-planning route; address in Tasks & Acceptance or decline under Design Notes. guard: AC: the demo opt-in seeds application errors, or the Logs demo names another write
- 2026-09-11T19:38:29Z status=resolved-by:1-4-one-command-brings-up-an-instance-with-ocupilot-installed by=adjudication note=deterministic $$LOG^%ETN seed confirmed readable at create; AC12 TestDemoSeedsAnApplicationError (Verification mutation line); smoke14 hook log shows the seeded entry

### DW-16: Installer creates the administrative resource and role but grants the role to nobody
- source: epics-review-findings.json | severity: med | fix-risk: low | footprint: in-story
- evidence: No one can configure the agent; the first-login gate never fires [epics-review edge-case-hunter E17; epics.md:996-999, 2081-2083 @8981cdf]
- 2026-09-09T15:10:48Z status=routed owner=1-3-the-installer-creates-ocupilot-s-protected-state-resource-an by=load note=edge-case-hunter lens, pre-planning route; address in Tasks & Acceptance or decline under Design Notes. guard: AC: install grants the role to the installing user, or documents the required grant
- 2026-09-10T00:34:23Z status=resolved-by:1-3-the-installer-creates-ocupilot-s-protected-state-resource-an by=adjudication note=AC9 EnsureGrant grants OcuPilotAdmin to $Username when it is a real named account (rejecting ''/UnknownUser/_PUBLIC per AD-21) and reports the exact operator grant command otherwise. Audited, idempotent, recorded on the stamp. Code review verified the close against the delivered code.

### DW-17: User types an arbitrarily large value into the editable max-rows field
- source: epics-review-findings.json | severity: med | fix-risk: low | footprint: in-story
- evidence: Unbounded fetch defeats the bounded-read rule and the two-second floor [epics-review edge-case-hunter E18; epics.md:1592-1594 @8981cdf]
- 2026-09-09T15:10:48Z status=routed owner=2-4-the-data-table by=load note=edge-case-hunter lens, pre-planning route; address in Tasks & Acceptance or decline under Design Notes. guard: AC: max rows clamps to a server-enforced ceiling and the clamp is reported
- 2026-09-13T02:25:46Z occurrence=1-14-the-auto-refresh-framework
- 2026-09-13T02:25:46Z status=routed owner=2-4-the-data-table by=cr note=ScreenStore.setMaxRows takes any number; maxRows() feeds every tick's AD-36 cap unvalidated
- 2026-09-14T02:47:20Z owner=2-4-the-data-table by=x0 note=excluded: the max-rows field is built by 2.4
- 2026-09-14T13:49:49Z status=resolved-by:2-4-the-data-table by=adjudication note=screen-store refuses a non-positive, non-integer or out-of-range max-rows value and the footer field reverts (matrix rows DW-17 bad cap and Cap raised); the ceiling half is by-design: no artifact publishes a ceiling and Story 2.3 closed it the same way

### DW-18: Active row vanishes on a silent re-fetch or filter change, not a delete
- source: epics-review-findings.json | severity: med | fix-risk: low | footprint: in-story
- evidence: aria-activedescendant points at a recycled row and focus is lost [epics-review edge-case-hunter E19; epics.md:1600-1604 @8981cdf]
- 2026-09-09T15:10:48Z status=routed owner=2-4-the-data-table by=load note=edge-case-hunter lens, pre-planning route; address in Tasks & Acceptance or decline under Design Notes. guard: AC: any re-fetch dropping the active row moves focus and selection exactly as a delete does
- 2026-09-13T02:25:46Z occurrence=1-14-the-auto-refresh-framework
- 2026-09-13T02:25:46Z status=routed owner=2-4-the-data-table by=cr note=clearAnswers() keeps selection+scroll on an AD-44 switch, so ids from the left namespace survive
- 2026-09-14T02:47:20Z owner=2-4-the-data-table by=x0 note=excluded: the active row exists only once 2.4 renders rows
- 2026-09-14T13:49:49Z status=resolved-by:2-4-the-data-table by=adjudication note=table-model reconciles the active row and selection after a re-fetch or filter change and a namespace switch clears them; table-model.test.mjs and data-table.browser-spec recycling cases

### DW-19: messages.log absent, unreadable, or the manager directory moved between calls
- source: epics-review-findings.json | severity: med | fix-risk: low | footprint: in-story
- evidence: Viewer shows an empty log, implying the instance logged nothing [epics-review edge-case-hunter E20; epics.md:1778-1788 @8981cdf]
- 2026-09-09T15:10:48Z status=routed owner=2-11-the-messages-log-paging-endpoint by=load note=edge-case-hunter lens, pre-planning route; address in Tasks & Acceptance or decline under Design Notes. guard: AC: a missing or unreadable source returns a named refusal, distinct from an empty page
- 2026-09-14T02:47:20Z owner=2-11-the-messages-log-paging-endpoint by=x0 note=excluded: the endpoint is built by 2.11
- 2026-09-15T05:39:01Z status=resolved-by:2-11-the-messages-log-paging-endpoint by=adjudication note=the endpoint resolves the manager directory per call and refuses by name: LOG.SOURCE for a key with no file, LOG.ABSENT when the resolved file is gone, LOG.UNAVAILABLE when it cannot be read; a rotation between calls restarts the page on either a changed first-line identity or an offset past the end, each pinned alone over the wire

### DW-20: The single default definition is disabled by an endpoint change or deleted
- source: epics-review-findings.json | severity: med | fix-risk: low | footprint: in-story
- evidence: Every user's panel silently stops working with no stated state [epics-review edge-case-hunter E21; epics.md:1863-1869 @8981cdf]
- 2026-09-09T15:10:48Z status=routed owner=3-1-agent-definitions-and-the-rules-that-keep-them-honest by=load note=edge-case-hunter lens, pre-planning route; address in Tasks & Acceptance or decline under Design Notes. guard: AC: define the fallback - promote another enabled definition, else the configuration-empty state

### DW-21: Endpoint hostname resolves to loopback, link-local or the instance itself
- source: epics-review-findings.json | severity: med | fix-risk: low | footprint: in-story
- evidence: SSRF to instance metadata or local services through a DNS name [epics-review edge-case-hunter E22; epics.md:1896-1898, 1962-1965 @8981cdf]
- 2026-09-09T15:10:48Z status=routed owner=3-2-the-provider-contract-and-the-anthropic-adapter by=load note=edge-case-hunter lens, pre-planning route; address in Tasks & Acceptance or decline under Design Notes. guard: AC: validate the resolved address at call time, not only the URL literal

### DW-22: Referenced environment variable or IRIS credential is missing when a turn runs
- source: epics-review-findings.json | severity: med | fix-risk: low | footprint: in-story
- evidence: Turns fail with an opaque error the ladder is forbidden to explain [epics-review edge-case-hunter E23; epics.md:1927-1931 @8981cdf]
- 2026-09-09T15:10:48Z status=routed owner=3-3-credentials-resolve-at-call-time-and-are-never-stored-where by=load note=edge-case-hunter lens, pre-planning route; address in Tasks & Acceptance or decline under Design Notes. guard: AC: an unresolvable credential fails the turn with a named reason and flags the definition

### DW-23: OcuPilot.Kernel.Utils has no dedicated test suite and no production call site in this story, so none of its non-trivial logic has ever actually execu…
- source: spec-1-1-the-workspace-the-pinned-stack-and-one-response-envelope.md | severity: med | fix-risk: med | footprint: in-epic
- evidence: Verified: grep for OcuPilot.Kernel.Utils under src/OcuPilot/ finds only the class's own header and one doc-comment mention in Api/Router.cls (prose, not a call). A 'no consumer in this story' note (mirroring Test.Http.cls's existing pattern) was added to the class now; authoring a full behavioral t…
- 2026-09-09T17:18:06Z status=routed owner=1-5-the-static-shell-serves-the-spa-including-deep-links by=harvest note=harvested from build-auto deferred: at dev_complete; spec severity medium
- 2026-09-09T21:26:31Z status=routed owner=1-3-the-installer-creates-ocupilot-s-protected-state-resource-an by=spec_gate note=re-owning from 1.5: Story 1.3's spec makes the installer the FIRST production consumer of Kernel.Utils (SwitchNamespace/RestoreNamespace) and plans the direct test host its header asks for. 1.5 was a placeholder guess at harvest time; 1.3 is where the code actually lands.
- 2026-09-10T00:34:23Z status=routed owner=1-6-silent-first-sign-in by=adjudication note=HALF closed by 1.3, re-owning the residue rather than resolving it. Closed: SwitchNamespace/RestoreNamespace now have production call sites and a direct test host. NOT closed: the non-trivial logic this entry's own evidence names has still never executed - DecodeUtf8Stream chunk carryover, ApplyOutputCeiling surrogate truncation, SanitizeError bracket scan. 1.6 is the first request carrying a body, alongside DW-24 on the same class.
- 2026-09-12T05:47:18Z status=routed owner=1-8-instance-identity-and-the-api-version-guard by=adjudication note=HALF closed: Test.Utils gives the class an executed host (9/9), so 'never executed' is gone. NOT closed: ReadRequestBody still has no production call site - the login POST is intercepted by the CSP server and never reaches it. 1.8 adds the first route that carries a body
- 2026-09-12T08:27:50Z status=routed owner=4-1-the-turn-runs-in-a-background-job-and-returns-immediately by=spec_gate note=correcting my own routing note: 1.8's whole surface is one GET, so it adds no body-carrying route. POST /api/ocupilot/turn is the first, per AD-7

### DW-24: Kernel.Utils.ReadRequestBody's inner fallback Catch (around %request.Content) silently reports a genuine read fault as an empty, successful body inst…
- source: spec-1-1-the-workspace-the-pinned-stack-and-one-response-envelope.md | severity: med | fix-risk: low | footprint: in-epic
- evidence: Traced directly: the inner Catch sets tStream='' and execution falls through to 'If '$IsObject($Get(tStream)) Quit', exiting with tSC still $$$OK. Real defect, but Kernel.Utils has zero consumers and zero test coverage in this story (see the companion deferred entry), so fixing this one path withou…
- 2026-09-09T17:18:06Z status=routed owner=1-6-silent-first-sign-in by=harvest note=harvested from build-auto deferred: at dev_complete; spec severity medium
- 2026-09-12T05:47:18Z status=resolved-by:1-6-silent-first-sign-in by=adjudication note=inner fallback Catch now reports the read fault; pinned by Test.Utils.TestReadRequestBodyReportsAReadFaultInsteadOfAnEmptyBody, whose red the reviewer demonstrated by mutating Kernel.Utils on the instance

### DW-25: OcuPilot.Api.Router.ReportHttpStatusCode's new $$$ISERR(pSC) branch (rendering an internal-error envelope when %CSP.REST itself passes a failing stat…
- source: spec-1-1-the-workspace-the-pinned-stack-and-one-response-envelope.md | severity: med | fix-risk: low | footprint: in-epic
- evidence: Verified via irislib/%CSP/REST.cls:351-421: OnPreDispatch's own error status is re-thrown by $$$ThrowOnError and caught by DispatchRequest's outer Try/Catch, which is the one call site that ever passes a genuine error pSC into ReportHttpStatusCode. No fixture route or test in this story forces OnPr…
- 2026-09-09T17:18:06Z status=routed owner=1-5-the-static-shell-serves-the-spa-including-deep-links by=harvest note=harvested from build-auto deferred: at dev_complete; spec severity medium
- 2026-09-12T01:32:13Z status=resolved-by:1-5-the-static-shell-serves-the-spa-including-deep-links by=adjudication note=AC10 plus Test.Envelope driving Test.PreFault: the ISERR branch renders exactly one internal-error envelope, detail logged not sent

### DW-26: No test asserts that Api.Error.RenderInternal's call into Kernel.Audit.Log.Error actually carries the exception's subsystem/message/detail correctly.
- source: spec-1-1-the-workspace-the-pinned-stack-and-one-response-envelope.md | severity: med | fix-risk: low | footprint: in-story
- evidence: Partially addressed: a real Flag/Severity argument-order defect in Kernel.Audit.Log.Emit was found and fixed this pass, with a new direct test (OcuPilot.Test.Log) pinning the class's own severity/flag mapping and never-throws contract. What remains untested is the specific RenderInternal -> Log.Err…
- 2026-09-09T17:18:06Z status=open owner=1-1-the-workspace-the-pinned-stack-and-one-response-envelope by=harvest note=harvested from build-auto deferred: at dev_complete; spec severity medium
- 2026-09-09T17:56:08Z occurrence=1-1-the-workspace-the-pinned-stack-and-one-response-envelope
- 2026-09-09T17:56:08Z status=open owner=1-1-the-workspace-the-pinned-stack-and-one-response-envelope by=cr note=cheaper now: Kernel.Audit.Log.WriteConsole seam added this pass, but RenderInternal calls Log by hard class name so a probe cannot intercept
- 2026-09-09T18:17:00Z status=resolved-by:1-1-the-workspace-the-pinned-stack-and-one-response-envelope by=adjudication note=fix pack added the Api.Error.LogError seam + Test.ErrorProbe + TestRenderInternalRoutesSubsystemMessageAndDetailThroughSeam; mutation (message literal changed) demonstrated red then reverted; Envelope 9->10 tests

### DW-27: The AC's 'bundle filenames carry content hashes' claim is tested only at the outputHashing:'all' config-knob level; nothing asserts on the actual bui…
- source: spec-1-1-the-workspace-the-pinned-stack-and-one-response-envelope.md | severity: low | fix-risk: low | footprint: in-story
- evidence: Verified by inspection of ui/tools/angular-json.test.mjs (asserts the config value only) and independently confirmed, by actually running npm run build in this pass, that the real output is hashed (main-ZVKF3V26.js, styles-5INURTSO.css) — so the AC currently holds, but nothing would catch a regress…
- 2026-09-09T17:18:06Z status=open owner=1-1-the-workspace-the-pinned-stack-and-one-response-envelope by=harvest note=harvested from build-auto deferred: at dev_complete; spec severity low
- 2026-09-09T17:56:08Z status=resolved-by:1-1-the-workspace-the-pinned-stack-and-one-response-envelope owner=1-1-the-workspace-the-pinned-stack-and-one-response-envelope by=cr note=QA added ui/tools/build-output.test.mjs; runs the real build, asserts hashed filenames; verified green

### DW-28: Kernel.Utils.ValidateInteger's doc comment says it accepts an 'optionally signed' integer, but the pattern match only accepts a leading '-', not '+'.
- source: spec-1-1-the-workspace-the-pinned-stack-and-one-response-envelope.md | severity: low | fix-risk: low | footprint: in-story
- evidence: Verified against the pattern (pValue '? 1.N && (pValue '? 1'-'1.N)): a value like '+5' satisfies neither branch and is rejected. This is a faithful harvest (AD-23) of pre-existing behavior with no call site in this story; correcting it in isolation from its harvest source is not this story's proble…
- 2026-09-09T17:18:06Z status=open owner=1-1-the-workspace-the-pinned-stack-and-one-response-envelope by=harvest note=harvested from build-auto deferred: at dev_complete; spec severity low
- 2026-09-09T18:17:00Z status=resolved-by:1-1-the-workspace-the-pinned-stack-and-one-response-envelope by=adjudication note=doc corrected to 'optionally negative'; pattern deliberately unchanged (no consumer yet). Live probe confirms +5 rejected, -5 accepted on the compiled class

### DW-29: Test.Http.RawRequest has no final Else branch for an unsupported HTTP method, unlike its sibling MakeRequest, which does.
- source: spec-1-1-the-workspace-the-pinned-stack-and-one-response-envelope.md | severity: low | fix-risk: low | footprint: in-story
- evidence: Verified by reading both methods side by side. Test.Http has no consumer in this story (Story 1.5 is its first, per Design Notes); the natural point to harden this helper is when it gets its first real caller and real usage patterns. [loc: src/OcuPilot/Test/Http.cls (RawRequest)]
- 2026-09-09T17:18:06Z status=open owner=1-1-the-workspace-the-pinned-stack-and-one-response-envelope by=harvest note=harvested from build-auto deferred: at dev_complete; spec severity low
- 2026-09-09T18:17:00Z status=resolved-by:1-1-the-workspace-the-pinned-stack-and-one-response-envelope by=adjudication note=RawRequest gained the final Else mirroring MakeRequest; mutation demonstrated (removing it raised <INVALID OREF> on a PATCH probe), reverted

### DW-30: ui/package.json declares a 'test'/'pretest' script but angular.json has no test architect target and no test runner is installed, so npm test cannot …
- source: spec-1-1-the-workspace-the-pinned-stack-and-one-response-envelope.md | severity: low | fix-risk: low | footprint: in-story
- evidence: Verified: angular.json defines only build/serve targets; package-lock.json resolves no karma/jasmine-core as installed dependencies. Real, but no AC in this story requires a working ng test, and Stories 1.2/1.9/1.10 add the first real UI code this story's own scope explicitly excludes — the natural…
- 2026-09-09T17:18:06Z status=open owner=1-1-the-workspace-the-pinned-stack-and-one-response-envelope by=harvest note=harvested from build-auto deferred: at dev_complete; spec severity low
- 2026-09-09T17:56:08Z occurrence=1-1-the-workspace-the-pinned-stack-and-one-response-envelope
- 2026-09-09T17:56:08Z status=open owner=1-1-the-workspace-the-pinned-stack-and-one-response-envelope by=cr note=partly addressed: test:tools script added so node --test tools/ is discoverable; ng test still has no architect target
- 2026-09-09T18:17:00Z status=resolved-by:1-1-the-workspace-the-pinned-stack-and-one-response-envelope by=adjudication note=npm test now runs node --test tools/ and exits 0 (17/17); mutation demonstrated (reverting to ng test fails 'Cannot determine project or target'). An ng test architect target remains a later story's work

### DW-31: Kernel.EntityId is a byte/Latin-1 percent codec, so a browser-encoded (UTF-8) entity id does not round-trip through the pair AD-13 designates as the only one
- source: spec-1-1-the-workspace-the-pinned-stack-and-one-response-envelope.md | severity: med | fix-risk: med | footprint: in-epic
- evidence: Probed live (ocupilot-iris/HSCUSTOM): Encode("cafe-acute") yields caf%E9 (Latin-1), while Decode("caf%C3%A9") - what encodeURIComponent produces and what AD-20's API service will send - returns a 5-character string that is not equal to the original. Both existing corpus tests pass because both halves of the trip are the same ObjectScript pair; neither exercises the client's encoding.
- 2026-09-09T17:56:23Z status=routed owner=1-5-the-static-shell-serves-the-spa-including-deep-links by=cr note=1.5 replays the corpus over the wire; settle there whether the codec transcodes UTF-8 or the gateway already decoded and Decode must not run
- 2026-09-09T18:18:19Z occurrence=1-1-the-workspace-the-pinned-stack-and-one-response-envelope
- 2026-09-09T18:18:19Z status=routed owner=1-5-the-static-shell-serves-the-spa-including-deep-links by=smoke note=lead smoke dispatched /items/caf%C3%A9%20bar in-process and got id='café bar' with HTTP 200 - a correct-looking UTF-8 round trip. That does NOT settle the finding: the MCP transport re-encodes strings, so this cannot distinguish a correct codec from a masked one. 1.5 must settle it over the wire, not through a tool layer.
- 2026-09-12T01:32:13Z status=resolved-by:1-5-the-static-shell-serves-the-spa-including-deep-links by=adjudication note=settled encode-twice/decode-once, AD-13 amended; Test.EntityId corpus replayed over the wire by Test.Wire and mirrored in ui/tools/entity-id.test.mjs

### DW-32: The structural XData UrlMap route-ordering check the spec's Design Notes promise does not exist in check-objectscript.py
- source: spec-1-1-the-workspace-the-pinned-stack-and-one-response-envelope.md | severity: med | fix-risk: med | footprint: in-epic
- evidence: Design Notes: 'the three invariants are enforced by a structural check over the router's XData UrlMap ... the structural check is what catches the first real violation in Story 1.5.' check-objectscript.py has exactly four checks (rename tokens, naming, write discipline, package placement); none parses UrlMap. The production Api/Router.cls UrlMap is empty, so the behavioural fixture tests cannot catch a violation in it either.
- 2026-09-09T17:56:23Z status=routed owner=1-5-the-static-shell-serves-the-spa-including-deep-links by=cr note=1.5 adds the first real routes; the promised gate must exist before they land or the invariants are unenforced
- 2026-09-09T18:00:07Z status=escalated owner=burndown by=cr note=fix-risk raised to high: correctness cannot be demonstrated in this story, the production UrlMap is empty so there is no route to validate a new checker rule against
- 2026-09-13T21:00:46Z status=routed owner=2-3-one-descriptor-declared-read-serves-both-the-screen-and-its by=merge_gate note=owner-delegated decision: build the structural UrlMap route-ordering check in check-objectscript.py. The blocker was an empty production UrlMap; 2-3 adds the first descriptor-declared routes, which is the population to validate the rule against
- 2026-09-14T02:47:20Z owner=2-3-one-descriptor-declared-read-serves-both-the-screen-and-its by=x0 note=excluded: med fix-risk; the check needs 2.3's descriptor routes to validate against
- 2026-09-14T11:04:08Z status=resolved-by:2-3-one-descriptor-declared-read-serves-both-the-screen-and-its by=adjudication note=check-objectscript.py route-ordering rule over XData UrlMap, validated against RouterFixture's three ordering cases and planted violations in test_check_objectscript.py

### DW-33: OnPreDispatch validates the resolved namespace and discards it, though the spec's Task item and Design Notes both say it stashes the result
- source: spec-1-1-the-workspace-the-pinned-stack-and-one-response-envelope.md | severity: med | fix-risk: low | footprint: in-epic
- evidence: Api/Router.cls:84-89 - tNs is used only for the %SYS.Namespace.Exists() test and goes out of scope. Nothing stashes it. The code itself is correct for this story (resolve once, validate, deny), but Design Notes name Story 1.11 as building namespace-as-data-scope on 'OnPreDispatch's single resolution point', which currently produces no consumable result.
- 2026-09-09T17:56:23Z status=routed owner=1-11-the-namespace-switch-as-data-scope by=cr note=1.11 must add the stash and its first consumer together; adding undemonstrated process-wide state now was rejected at review
- 2026-09-12T19:18:18Z status=resolved-by:1-11-the-namespace-switch-as-data-scope by=adjudication note=the resolved namespace is stashed in Kernel.Scope at OnPreDispatch and read by two consumers in the same story; pinned in-process and through the real router

### DW-34: Api.Router.ReportHttpStatusCode's Else branch and Api.Error.GetSlugForStatus ship reachable but untested, and emit a numeric machine code the Design Notes rule out
- source: spec-1-1-the-workspace-the-pinned-stack-and-one-response-envelope.md | severity: med | fix-risk: low | footprint: in-epic
- evidence: Reachable, not theoretical: %CSP.REST.Page() at irislib/%CSP/REST.cls:169 calls ..Http403() on a security-application failure, which reaches this override with pSC=$$$OK and takes the Else branch. That branch emits code "ROUTE." _ tStatus (ROUTE.403), while the spec's Design Notes settle code as 'a stable dotted uppercase identifier ... rather than a number'. GetSlugForStatus's twelve-way mapping is called only from this branch and has no test; inverting any pair leaves all 28 tests green.
- 2026-09-09T17:56:40Z status=routed owner=1-5-the-static-shell-serves-the-spa-including-deep-links by=cr note=1.5 is the first story with a live web app where Page() runs; fix the code format and add direct GetSlugForStatus assertions there
- 2026-09-09T18:04:10Z status=routed owner=1-5-the-static-shell-serves-the-spa-including-deep-links by=adjudication note=numeric-code half fixed in-story (code now ROUTE.<SLUG>) with a demonstrated mutation; residual is the Else branch having no dispatch-level test. This update was mis-appended to DW-35 at review.
- 2026-09-12T01:32:13Z status=resolved-by:1-5-the-static-shell-serves-the-spa-including-deep-links by=adjudication note=AC10 second half; Test.Envelope pins a slug-derived code that is never numeric. Residue on dotted ids is DW-97, routed to 1.9

### DW-35: check-objectscript.py is the pinning gate for four ACs and has no test of its own; AC-5 is evidenced only by one-off manual runs against throwaway scratch trees
- source: spec-1-1-the-workspace-the-pinned-stack-and-one-response-envelope.md | severity: med | fix-risk: med | footprint: in-epic
- evidence: Searched the repo for 'check-objectscript': only .githooks/pre-commit and the script's own docstring. No test file executes it. This review found three real gaps in it that the implement-stage pass missed (the %OnNew p-prefix rule still blocking the framework signature .claude/rules mandates, write discipline skipping .mac/.inc, and the pre-commit pathspec never matching a class directly under src/OcuPilot/) - evidence that 'green' and 'the rules silently stopped matching' are currently the same observable.
- 2026-09-09T17:56:40Z status=routed owner=1-17-the-smoke-script-the-readiness-endpoint-and-ci by=cr note=1.17 owns CI and is where a fixture-tree test gets both a runner and a discovering command (Rule 8)
- 2026-09-09T18:00:07Z status=routed owner=1-5-the-static-shell-serves-the-spa-including-deep-links by=cr note=numeric-code half FIXED in-story (code now ROUTE.<SLUG>) + Test.SlugForStatusMapping added, mutation demonstrated; residual is only the Else branch having no dispatch-level test
- 2026-09-09T18:04:10Z status=routed owner=1-17-the-smoke-script-the-readiness-endpoint-and-ci by=adjudication note=re-owning to 1.17 per the entry's own first routing; the 18:00 trailer's owner and note belonged to DW-34 and were mis-appended here
- 2026-09-09T20:02:02Z occurrence=1-2-the-design-system-tokens-type-and-the-string-table
- 2026-09-09T20:02:02Z status=routed owner=1-17-the-smoke-script-the-readiness-endpoint-and-ci by=harvest note=Story 1.2 added a third rule (check_product_vocabulary) to the same untested checker, verified only by a one-time manual mutation - the gap now spans two stories' rules
- 2026-09-09T20:42:50Z status=routed owner=1-17-the-smoke-script-the-readiness-endpoint-and-ci by=adjudication note=correction to my 20:02 trailer - check_product_vocabulary is the fifth check in main(), not the third. The entry's substance is unchanged: the checker is a commit-blocking gate with no test of its own.
- 2026-09-13T15:59:59Z status=resolved-by:1-17-the-smoke-script-the-readiness-endpoint-and-ci by=adjudication note=scripts/test_check_objectscript.py, 45 tests OK, lead-verified. The gate that pins four ACs now has its own harness rather than one-off manual runs

### DW-36: CLAUDE.md's Running-and-verifying section is stale: it does not mention check-objectscript.py, now a commit-blocking gate, and still says the Angular build and test invocations are a TODO
- source: spec-1-1-the-workspace-the-pinned-stack-and-one-response-envelope.md | severity: med | fix-risk: low | footprint: in-epic
- evidence: CLAUDE.md 'Running and verifying' documents only scripts/lint-docs.sh and carries 'TODO once code exists: the Angular build and test invocations', but this story added scripts/check-objectscript.py to .githooks/pre-commit and created ui/ with npm run build and node --test tools/. CLAUDE.md is the first file every agent reads, so a later story's spawn inherits an understated gate list. Deferred rather than patched because step-04 routes any fix that edits an agent-context file to defer.
- 2026-09-09T17:56:40Z status=routed owner=burndown by=cr note=no single story owns CLAUDE.md; fold into the epic burn-down alongside the other repo-hygiene items
- 2026-09-11T13:27:48Z occurrence=1-4-one-command-brings-up-an-instance-with-ocupilot-installed
- 2026-09-11T13:27:48Z by=cr note=CLAUDE.md's intro still says src/OcuPilot/ is empty and ui/ does not exist
- 2026-09-11T14:51:18Z by=lead note=CLAUDE.md intro and Running section sit inside the bmad:context managed block; fix through a bmad-project-context refresh, not a hand edit
- 2026-09-13T14:48:40Z occurrence=1-17-the-smoke-script-the-readiness-endpoint-and-ci
- 2026-09-13T14:48:40Z status=routed owner=burndown by=harvest note=1.17 widens it: CLAUDE.md now also omits npm test, scripts/smoke.sh, scripts/ci-throwaway.sh and the existence of CI. The TODO this entry names is the one 1.17 closed. Deferred there rather than patched because the fix edits an agent-context file
- 2026-09-13T18:11:21Z status=resolved-by:1-17-the-smoke-script-the-readiness-endpoint-and-ci by=burndown note=CLAUDE.md's Running-and-verifying section rewritten in 803305b: npm run build with its five prebuild checkers, npm test, npm run test:browser, check-objectscript.py and its harness, smoke.sh, and CI as the gate over what was committed including its cancel-in-progress concurrency

### DW-37: Two I/O & Edge-Case Matrix rows -- 'Non-role color literals are quarantined' and 'Scale and metrics' -- have real, passing pinning tests but no corre…
- source: spec-1-2-the-design-system-tokens-type-and-the-string-table.md | severity: low | fix-risk: low | footprint: in-story
- evidence: The Mutations list under `## Verification` predates this implementation (unchanged by this diff) and never covered either row. Both rows are still covered by a real, passing test (design-tokens.test.mjs's non-role-literal tests; typography.test.mjs's scale/radii/heights/metrics tests), so the Matri…
- 2026-09-09T20:02:03Z status=open owner=1-2-the-design-system-tokens-type-and-the-string-table by=harvest note=harvested at dev_complete; Rule 19 gap - passing tests exist but no mutation: line records their falsifiability
- 2026-09-09T20:42:50Z status=resolved-by:1-2-the-design-system-tokens-type-and-the-string-table by=adjudication note=QA demonstrated both missing mutations (logo-gradient-stop moved into COLOR_ROLES; radius-md 6px->8px) and the code review independently re-applied both and confirmed red with the logged messages. All 17 matrix rows now carry a mutation line.

### DW-38: The vendored OFL licence texts do not travel with the woff2 faces into the redistributed bundle
- source: spec-1-2-the-design-system-tokens-type-and-the-string-table.md | severity: med | fix-risk: low | footprint: in-epic
- evidence: angular.json's assets is [] and only url()-referenced files are copied, so dist/ocupilot-ui/browser/media/ holds the five hashed woff2 and no licence text (verified after a real build). dist/ocupilot-ui/3rdpartylicenses.txt is esbuild's npm extract, one directory above the served root, and does not name Inter or JetBrains Mono. SIL OFL 1.1 section 2 requires the notice to accompany each distributed copy of the Font Software; near-universal web practice ships webfonts without a co-located licence, so whether the source-tree copy suffices is a call, not a defect. The story's Task list also says angular.json needs only the styles edit.
- 2026-09-09T20:39:36Z status=decision-pending owner=burndown by=cr note=legal/packaging call for the decision sheet; candidate homes are angular.json assets, an ATTRIBUTIONS file, or the IPM module (1.16)
- 2026-09-11T22:38:45Z occurrence=1-5-the-static-shell-serves-the-spa-including-deep-links
- 2026-09-13T14:46:52Z status=by-design by=decision-sheet note=both OFL texts now ship beside the faces - angular.json assets copies them into browser/media/, verified against a real build - and ATTRIBUTIONS.md records the source-tree half. module.xml FileCopy already carries that directory, so the IPM distribution is covered too

### DW-39: The dark class flip does not reach the 34 OcuPilot-only color roles, only the 30 with a --mat-sys-* counterpart
- source: spec-1-2-the-design-system-tokens-type-and-the-string-table.md | severity: med | fix-risk: med | footprint: in-story
- evidence: Parsed the emitted styles-<hash>.css: the :root.ocu-theme-dark block re-points 30 --mat-sys-* variables and redefines 0 --ocu-* roles. --ocu-shell: #0f3a5f is the only declaration of that name anywhere and nothing under the dark scope changes it, so var(--ocu-shell) is light in both modes. Story 1.10 is named in Design Notes as the first surface drawing shell / on-shell / shell-edge and would have to hand-pick var(--ocu-<role>-dark) per call site, which is not the story's stated 'the flip is a class flip'. The spec's own mechanism sketch shows only --mat-sys-* re-points, so the two readings conflict.
- 2026-09-09T20:39:47Z status=escalated owner=burndown by=cr note=not patched: completing it is a design decision the spec sketch does not show, serving a toggle the spine defers to FR-73; color-scheme half fixed in-story
- 2026-09-13T14:46:52Z status=routed owner=15-6-the-light-and-dark-theme by=decision-sheet note=the 34 --ocu-* dark values are 15.6's, alongside DW-118 which is the same defect from the other side. FR-73 defers the toggle, and designing 34 dark values now means checking them against no dark surface

### DW-40: client-lint reports a hex-shaped URL fragment or SVG sprite id as a hardcoded color
- source: spec-1-2-the-design-system-tokens-type-and-the-string-table.md | severity: low | fix-risk: low | footprint: in-story
- evidence: Verified: checkHardcodedColors({text: '<a href="#abcdef">x</a>'}) reports #abcdef under no-hardcoded-color. HEX_COLOR_RE does not care what precedes the #. No anchor, SVG sprite reference or hex-shaped fragment exists anywhere under ui/src today, and the linter's own header states it is a regex scanner rather than a CSS/HTML parser.
- 2026-09-09T20:39:47Z status=wontfix-theoretical owner=burndown by=cr note=would become real the first time a template writes href=#<3,4,6 or 8 hex chars> or url(sprite.svg#dad) and fails npm run build

### DW-41: The token layer ships with no base rule, so nothing on the page draws a token and the dark scope is unobservable
- source: spec-1-2-the-design-system-tokens-type-and-the-string-table.md | severity: low | fix-risk: low | footprint: in-epic
- evidence: grep over src/styles.scss and the four partials finds no html/body rule setting background, color or margin; _theme.scss's html selector exists only to host mat.theme(). The shipped page therefore renders on the UA default white with the UA body margin, and adding .ocu-theme-dark changes nothing observable. The story deliberately ships no component, screen or chrome, so there is no surface to draw one yet.
- 2026-09-09T20:39:57Z status=wontfix-accepted owner=burndown by=cr note=reopen_if=Story 1.10's shell renders on a UA-default white background or with a non-zero body margin

### DW-42: The un-sourced-copy lint does not reach index.html or any template outside ui/src/app
- source: spec-1-2-the-design-system-tokens-type-and-the-string-table.md | severity: low | fix-risk: low | footprint: in-story
- evidence: lintClient() gates checkTemplateLiterals on path.startsWith('src/app/'), so src/index.html is scanned for colors only -- and it carries <title>OcuPilot</title>, user-facing copy that strings.ts's own header says productName exists for. The AC scopes the rule to 'any component template under ui/src/app', so the shipped behaviour matches the AC as written; widening it is a scope change, not a correction.
- 2026-09-09T20:39:57Z status=wontfix-accepted owner=burndown by=cr note=reopen_if=a second un-sourced literal appears outside src/app (a manifest name, a meta description, or a title that drifts from STRINGS.productName)

### DW-43: Literal non-ASCII characters remain in four Story 1.1 source files, against the Rule 14 escape convention the spine now fixes
- source: spec-1-2-the-design-system-tokens-type-and-the-string-table.md | severity: low | fix-risk: low | footprint: in-epic
- evidence: Code review found literal em-dashes in ui/src/main.ts:6, ui/tools/version-guard.mjs, ui/tools/version-guard.test.mjs and ui/tools/angular-json.test.mjs - all authored by Story 1.1, before the Client asset homes conventions row made the \uXXXX rule explicit. Story 1.2's own three literals were escaped this pass. No test enforces the convention on ui/, so it will drift again.
- 2026-09-09T20:42:50Z status=routed owner=1-17-the-smoke-script-the-readiness-endpoint-and-ci by=cr note=1.17 owns CI and is where a tree-wide non-ASCII check gets both a runner and a discovering command
- 2026-09-13T08:52:07Z status=wontfix-accepted owner=1-17-the-smoke-script-the-readiness-endpoint-and-ci by=spec_gate note=comment half declined on re-measured evidence: 259 lines across 42 files, 275 characters, 242 of them em dashes, overwhelmingly in comments - which Rule 14 explicitly exempts as prose. The string-literal and template half IS addressed by a new checker in this story. reopen_if=Rule 14 is amended to cover comments, or a literal non-ASCII byte appears in a string literal or template

### DW-44: Install re-emits the RoleGranted audit marker on every run, so an idempotent no-op install writes an audit row for a grant that did not happen
- source: spec-1-3-the-installer-creates-ocupilot-s-protected-state-resource-an.md | severity: med | fix-risk: med | footprint: in-story
- evidence: Verified live on ocupilot-iris: %SYS.Audit holds 426 ROLEGRANTED and 415 ROLEGRANTEDPROBE rows for a role granted once, one per Install() call. EnsureGrant has no already-held branch: it calls Security.Users.AddRoles and $System.Security.Audit unconditionally. AD-15 ties the marker to a write; AC10 forces exactly this already/now distinction on the sibling auditing step. But AC9's own text reads 'when install completes ... an audit row is written', which blesses the current behaviour, and AD-46 makes these rows visible in OcuPilot's own audit screen. Whether an idempotent re-install should re-audit is a product call the AC does not settle.
- 2026-09-10T00:30:34Z status=decision-pending owner=burndown by=cr note=Not patched: gating the emission would contradict AC9 as literally worded and would flip TestGrantForRealAccountGrantsAndAudits, whose row-count assertion is the same AC's evidence. Decide once at the epic decision sheet.
- 2026-09-13T21:00:46Z status=routed owner=3-8-every-configuration-change-is-resource-gated-and-audited by=merge_gate note=owner-delegated decision: emit RoleGranted only on an actual grant and reword AC9, flipping TestGrantForRealAccountGrantsAndAudits. 3-8 owns audit semantics for configuration changes and AD-46 surfaces these rows

### DW-45: EnsureAuditingEnabled's enable branch, the README's headline security-posture change, is executed by no test
- source: spec-1-3-the-installer-creates-ocupilot-s-protected-state-resource-an.md | severity: low | fix-risk: med | footprint: in-story
- evidence: Auditing is already on on this instance, so Install always takes the already-enabled branch. TestSecondRunReportsAuditingAlreadyEnabled asserts the enable branch did NOT run. Replacing the Else body with a no-op, or misspelling the AuditEnabled key, leaves the whole suite green. On a fresh Community container with auditing off, install would report success and enable nothing, and FR-66's audit trail would be silently absent.
- 2026-09-10T00:30:44Z status=wontfix-accepted owner=1-3-the-installer-creates-ocupilot-s-protected-state-resource-an by=cr note=reopen_if=a fresh container whose AuditEnabled reads 0 still reads 0 after Install(). Not closed here: the spec's own Never list forbids a test writing AuditEnabled, and the only other closure adds a production read-seam purely for a test.
- 2026-09-10T01:13:21Z occurrence=1-4-one-command-brings-up-an-instance-with-ocupilot-installed
- 2026-09-10T01:13:21Z status=routed owner=1-4-one-command-brings-up-an-instance-with-ocupilot-installed by=spec_gate note=reopen_if fired at the 1.4 plan gate. EnsureAuditingEnabled's enable branch has never executed in this project's history; 1.4's AC2 runs it for the first time in a throwaway container, where a 0 return is a real failure rather than a flake. Re-owned from wontfix-accepted to the story that now exercises it.
- 2026-09-11T10:14:23Z occurrence=1-4-one-command-brings-up-an-instance-with-ocupilot-installed
- 2026-09-11T10:14:23Z status=routed owner=1-4-one-command-brings-up-an-instance-with-ocupilot-installed by=harvest note=still never executed. Every fresh container this image produces starts with AuditEnabled=1 (four fresh containers confirmed), so EnsureAuditingEnabled's enable branch has no natural path to run. Earlier spec text claiming a throwaway run exercised it has been marked corrected.
- 2026-09-11T19:38:29Z status=resolved-by:1-4-one-command-brings-up-an-instance-with-ocupilot-installed by=adjudication note=enable branch executed by Test.AuditEnable.TestEnableBranchTurnsAuditingOn without writing AuditEnabled (mutation run 435); live sweep run 603 3/3

### DW-46: OcuPilot.Test.Demo TestDemoTaskIsSuspendedAfterAnError is flaky on this specific long-lived ocupilot container (Task Manager daemon latency growing w…
- source: spec-1-4-one-command-brings-up-an-instance-with-ocupilot-installed.md | severity: med | fix-risk: med | footprint: in-story
- evidence: Verified live, repeatedly, in review: OcuPilot.Install.Fixture's demo task fixture (RunNow + poll for Suspended>0) is functionally correct -- a standalone classmethod call (bypassing %UnitTest) reached Suspended=1 in ~50s on one attempt and ~150s on another, both same-session -- but OcuPilot.Test.D…
- 2026-09-10T15:37:03Z status=open owner=1-4-one-command-brings-up-an-instance-with-ocupilot-installed by=harvest note=harvested at dev_complete; spec severity med
- 2026-09-10T16:01:33Z status=open owner=1-4-one-command-brings-up-an-instance-with-ocupilot-installed by=adjudication note=ROOT CAUSE FOUND and it is not daemon latency. %SYS.TaskSuper.QueryTasks populates its output array at subscript 0, and ObjectScript evaluates 0 '= "" as FALSE (the empty string numifies to 0). Install/Fixture.cls guards its QueryTasks iterations with '= "" in at least two places (line 258 CreateTask id extraction, lines 457-458 the Remove delete loop), so the demo task is never found and never deleted while Remove still returns OK. Confirmed live: Remove('probe') returned 1 and left task 1022 on the instance. Report loops are safe - Report() uses $Increment, which starts at 1.
- 2026-09-10T17:24:51Z status=resolved-by:1-4-one-command-brings-up-an-instance-with-ocupilot-installed by=adjudication note=CORRECTION - the subscript-0 mechanism I attached to this entry is disproven (see DW-53). Test.Demo's redness had two real sources, neither of them that: (1) RemoveOne's discarded %DeleteId status leaving stale tasks, now fixed; (2) iris_execute_tests re-submitting on client timeout, producing ~5 concurrent server-side runs racing on the same name-keyed %SYS.Task row - filed separately.
- 2026-09-11T04:02:03Z status=open owner=1-4-one-command-brings-up-an-instance-with-ocupilot-installed by=adjudication note=DIAGNOSIS CORRECTED AGAIN, by the lead, from run 304 read out of %UnitTest_Result. The red method is TestDemoSeedsAnApplicationError, NOT TestDemoTaskIsSuspendedAfterAnError - the latter PASSED after waiting 180s, so the daemon is alive and did run the task. The red one fails in 17ms on two assertions: no error-log entry since this run's floor, and no inventory row. Cause: Fixture.CreateErrorEntry runs inside Create() and confirms an entry that only exists AFTER the daemon has run the demo task, which in this same run took 180s. The fixture's confirmation races the daemon by design. Not 'daemon dead' (it serviced scheduled tasks today, $H day 67824) and not a narrow 59s granularity window.
- 2026-09-11T07:35:33Z status=open owner=1-4-one-command-brings-up-an-instance-with-ocupilot-installed by=adjudication note=CORRECTION TO MY OWN 04:02 TRAILER, per the owner's hand-off (2026-09-11, _bmad-output/party-mode/handoff-story-1-4-task-fixture-2026-09-11.md). I wrote that TestDemoTaskIsSuspendedAfterAnError 'PASSED after waiting 180s, so the daemon is alive and did run the task'. That inference was invalid: the pass was the SKIP branch, reached because the grace loop re-opened the task with %OpenId while still holding the previous OREF, and %Library.Persistent.%Open returns the in-memory OREF without reloading unless concurrency is upgraded past 2 (irislib line 727). The test has never observed a suspended task; every pass was the skip. Run 314 proves it: task 1047 was suspended by the daemon at 07:13 while the test polled until 07:15 and skipped. Real causes: (1) both wait loops poll a frozen object; (2) inference, to verify - the fixture holds the task OREF across RunNow and its whole wait, blocking the daemon, which is why 13 of 13 fixture tasks ran at Create+6min, one poll after the 5-min wait ended. The '50s->150s->240s+ latency' seen in earlier rounds was the fixture's own wait plus one poll.
- 2026-09-11T10:14:23Z status=resolved-by:1-4-one-command-brings-up-an-instance-with-ocupilot-installed by=adjudication note=closed. Both defects fixed in rework 5 (ff81766). Defect 1: Fixture and Test.Demo now drop the OREF before every %OpenId re-read, so the poll sees the daemon's write. Defect 2 is no longer an inference - observed: after RunNow the caller holds an exclusive lock on the task while it keeps the object, and the Task Manager runs RunNow requests only on its once-a-minute pass and skips a locked task, so the old 300s wait blocked the run it was waiting for. Fixture.CreateTask now releases the object and returns. The test owns the wait, re-reads freshly, has no SKIP branch, and now observes a real suspension at 40-55s. Rule 19 mutation (DemoTask.OnTask returns $$$OK) demonstrated red.

### DW-47: OcuPilot.Kernel.State.Version has no unique constraint on Profile, so two overlapping Install()/StartPath() calls for the same profile could create t…
- source: spec-1-4-one-command-brings-up-an-instance-with-ocupilot-installed.md | severity: med | fix-risk: low | footprint: in-story
- evidence: Verified by code read (2026-09-10 review): EnsureVersion does a read-then- insert-or-update with no transaction and no unique index on Profile; two concurrent Install() calls for the same profile could both read 'no row' and both insert, leaving two rows GuardedCurrentForProfile's TOP-1-ORDER-BY-ID…
- 2026-09-10T15:37:03Z status=open owner=1-4-one-command-brings-up-an-instance-with-ocupilot-installed by=harvest note=harvested at dev_complete; spec severity medium
- 2026-09-11T13:27:48Z occurrence=1-4-one-command-brings-up-an-instance-with-ocupilot-installed
- 2026-09-11T13:27:48Z by=cr note=deferral premise incomplete: a Lock +^OcuPilot... on the profile around Install closes the race with no schema v2
- 2026-09-11T14:51:18Z status=open owner=1-4-one-command-brings-up-an-instance-with-ocupilot-installed by=lead note=fix-now under Rule 15 (med, fix-risk low, in-story): lock on the profile around Install and the DW-72 mark; rework 8
- 2026-09-11T19:38:29Z status=resolved-by:1-4-one-command-brings-up-an-instance-with-ocupilot-installed by=adjudication note=install lock ^|%SYS|OcuPilotInstallLock(profile) around Install, MarkInstalling, Uninstall and StartPath (no schema v2 index needed); Test.InstallLock pins, live run 614 6/6, mutations t9 run 9 and cr4 runs 9-14

### DW-48: The container start hook compiles the entire src/OcuPilot/ tree, including every Test.* fixture/fault-injection class, into the production instance
- source: spec-1-4-one-command-brings-up-an-instance-with-ocupilot-installed.md | severity: med | fix-risk: med | footprint: in-story
- evidence: Real, and this story is what makes 'compile the whole source tree on every container start' the actual shipped mechanism (previously loaded ad hoc via MCP tools). Explicitly directed by this spec's own Code Map/Design Notes ('the start hook loads and compiles the src/OcuPilot/ tree ... no roster fi…
- 2026-09-10T15:37:03Z status=open owner=1-4-one-command-brings-up-an-instance-with-ocupilot-installed by=harvest note=harvested at dev_complete; spec severity medium
- 2026-09-10T21:44:22Z status=escalated owner=burndown by=cr note=fix-risk high: exclusion needs a roster AD-17 forbids or a tree move that changes FIXED_PACKAGES and 1.16 module.xml input; decision sheet
- 2026-09-11T13:27:48Z occurrence=1-4-one-command-brings-up-an-instance-with-ocupilot-installed
- 2026-09-11T13:27:48Z by=cr note=a compile error in any Test.* class now fails every start; Install.DemoTask ships on every path, flag off too
- 2026-09-13T21:00:47Z status=routed owner=17-2-a-readme-whose-install-steps-work-the-first-time by=merge_gate note=owner-delegated decision: move Test.* to a sibling tree excluded from the start hook and module.xml. A compile error in any test class fails every container start and DemoTask ships with the flag off, which is exactly what a first-time install must not do

### DW-49: A private RSA key (the demo X.509 fixture credential) is checked into OcuPilot.Install.Fixture.cls source
- source: spec-1-4-one-command-brings-up-an-instance-with-ocupilot-installed.md | severity: med | fix-risk: high | footprint: in-epic
- evidence: Real secret-scanner-shaped concern (Blind Hunter, 2026-09-10 review). By design per Fixture.cls's own documented rationale: there is no supported ObjectScript API to generate an X.509 certificate at install time, and shelling out to an external tool was rejected as the undocumented-internals risk A…
- 2026-09-10T15:37:03Z status=escalated owner=burndown by=harvest note=harvested at dev_complete; spec severity medium
- 2026-09-11T13:27:48Z occurrence=1-4-one-command-brings-up-an-instance-with-ocupilot-installed
- 2026-09-11T13:27:48Z by=cr note=PKI.CAServer.Configure generates a CA cert+key to files (%ZHSLIB.TLS.Utils uses it); header corrected
- 2026-09-13T18:42:36Z status=routed owner=burndown by=merge_gate note=owner decision 2026-09-13: generate the demo pair at each demo install; a checked-in key is explicitly acceptable as the fallback if the generate path does not land. This is a self-signed CN=OcuPilotDemo prop that secures nothing, so the exposure was always scanner noise rather than compromise - the 2026-09-24 deadline no longer applies and history rewriting is off the table. Chartered into the Epic 1 burn-down story with DW-59
- 2026-09-13T18:47:58Z status=wontfix-accepted by=merge_gate note=owner decision 2026-09-13 revised: keep the checked-in demo pair for Release 1 and charter generate-at-install as its own later story rather than burn-down work. It is a self-signed CN=OcuPilotDemo prop securing nothing. Burn-down carries only the marking work - state in the class header and beside the literal that the pair is a disposable demo fixture. reopen_if=the pair is ever used for anything but the demo fixture, or a scanner finding is judged unacceptable at launch
- 2026-09-13T18:48:17Z status=routed owner=burndown by=merge_gate note=correcting the trailer above - it closed the entry terminal while naming residual marking work, which leaves that work owned by nothing (the exact defect DW-223 names). The owner's accept-the-checked-in-pair decision stands; this entry stays open until the class header and the literal say the pair is a disposable demo fixture, and closes then
- 2026-09-13T21:00:47Z status=routed owner=6-3-the-x-509-ldap-kerberos-and-wallet-lists by=burndown note=owner decision recorded: keep the checked-in demo pair; residual is marking it a disposable fixture in the class header and beside the literal. 6-3 is the story that displays the credential, so the marking lands where its consumer is built

### DW-50: AC1-AC3/AC9-AC12's container, health-check, HTTP, and shell-level (demo-flag propagation) surfaces are verified only by a one-off manual throwaway-co…
- source: spec-1-4-one-command-brings-up-an-instance-with-ocupilot-installed.md | severity: med | fix-risk: med | footprint: in-epic
- evidence: Three reviewers converged on the same root cause from different angles (2026-09-10 review): verification-gap found StartPath(1)'s production-profile demo-fixture branch (the exact call docker-compose.yml's own OCUPILOT_DEMO=1 wires up) has zero %UnitTest coverage; the intent-alignment auditor separ…
- 2026-09-10T15:37:03Z status=routed owner=1-17-the-smoke-script-the-readiness-endpoint-and-ci by=harvest note=harvested at dev_complete; spec severity medium
- 2026-09-10T21:44:22Z occurrence=1-4-one-command-brings-up-an-instance-with-ocupilot-installed
- 2026-09-10T21:44:22Z status=routed owner=1-17-the-smoke-script-the-readiness-endpoint-and-ci by=cr note=routing honest for container/HTTP/shell; AC9 sslconfig+x509+webapp props need no container and stay in 1.4
- 2026-09-11T13:27:48Z occurrence=1-4-one-command-brings-up-an-instance-with-ocupilot-installed
- 2026-09-11T18:15:59Z occurrence=1-4-one-command-brings-up-an-instance-with-ocupilot-installed
- 2026-09-11T18:15:59Z by=lead note=DW-87: F-1's production half belongs to the scripted throwaway coverage this entry routes to Story 1.17
- 2026-09-11T19:26:37Z occurrence=1-4-one-command-brings-up-an-instance-with-ocupilot-installed
- 2026-09-11T19:26:37Z by=cr note=cr round 4: 4 hook mutations passed the text pins (field, !=, exit in mark, marker spelling); pinned; 1.17's run should repeat them
- 2026-09-13T15:59:59Z status=resolved-by:1-17-the-smoke-script-the-readiness-endpoint-and-ci by=adjudication note=CI's three jobs plus scripts/ci-throwaway.sh and scripts/smoke.sh execute the container, health-check, HTTP and demo-flag surfaces; ci.test.mjs pins the wiring. Residual that CI has never run as a workflow is DW-214, not this entry

### DW-51: ReportGatewayGap's Web Gateway timeout reader matches 'Server_Response_Timeout' as an unanchored substring, so a comment or unrelated CSP.ini line co…
- source: spec-1-4-one-command-brings-up-an-instance-with-ocupilot-installed.md | severity: low | fix-risk: low | footprint: in-story
- evidence: Real (Edge Case Hunter, 2026-09-10 review) but low-impact: the value is reported as information only and never modifies anything (AD-17/AD-27). Anchoring the match correctly needs this build's actual CSP.ini comment conventions, not verified in the time available for this review. [loc: ]
- 2026-09-10T15:37:03Z status=open owner=1-4-one-command-brings-up-an-instance-with-ocupilot-installed by=harvest note=harvested at dev_complete; spec severity low
- 2026-09-11T19:38:29Z status=resolved-by:1-4-one-command-brings-up-an-instance-with-ocupilot-installed by=adjudication note=config-file reader anchored and the fallback path corrected; Test.GatewayIni pins both readers (Verification DW-51 mutation); live run 602 3/3; closure verified by cr round 3

### DW-52: A narrow race in Fixture.CreateTask: the demo task's id could be deleted between QueryTasks and the following %OpenId, misreporting as 'not yet suspe…
- source: spec-1-4-one-command-brings-up-an-instance-with-ocupilot-installed.md | severity: low | fix-risk: low | footprint: in-story
- evidence: Real (Edge Case Hunter, 2026-09-10 review) but narrow and low-probability -- requires something else to delete the fixture's own task between two back-to-back reads in the same method. Deferred rather than rushed. [loc: ]
- 2026-09-10T15:37:03Z status=open owner=1-4-one-command-brings-up-an-instance-with-ocupilot-installed by=harvest note=harvested at dev_complete; spec severity low
- 2026-09-11T19:38:29Z status=resolved-by:1-4-one-command-brings-up-an-instance-with-ocupilot-installed by=adjudication note=the fixture no longer polls the task after RunNow (owner's never-wait decision, rework 5), so the QueryTasks-to-%OpenId window no longer reports a suspension state; closure verified by cr round 3

### DW-53: Install.Fixture.Remove silently deletes no demo task: its QueryTasks loop is guarded by '= "" which is false at subscript 0, so teardown returns OK having removed nothing
- source: spec-1-4-one-command-brings-up-an-instance-with-ocupilot-installed.md | severity: high | fix-risk: low | footprint: in-story
- evidence: Verified live: Fixture.Remove('probe') returned %Status 1 while task 1022 (OcuPilotDemo nightly purge) remained in %SYS.Task. Same trap at Fixture.cls:258. Breaks AD-25's inventory promise that uninstall removes exactly what install created, and makes Test.Demo order-dependent - tasks accumulate across runs.
- 2026-09-10T16:01:33Z status=open owner=1-4-one-command-brings-up-an-instance-with-ocupilot-installed by=adjudication note=found by the lead at the QA gate after the QA stage returned early; fix in the rework iteration
- 2026-09-10T17:24:51Z status=resolved-by:1-4-one-command-brings-up-an-instance-with-ocupilot-installed by=adjudication note=CORRECTION - my stated mechanism was WRONG and is disproven. I claimed 0 '= "" is FALSE at subscript 0; verified live it is TRUE (ObjectScript = is string equality, and "" is never a canonical number). The $Data(arr(sub)) idiom I prescribed is itself unsafe: $Data(a("")) throws <SUBSCRIPT> unconditionally on this build. The SYMPTOM I observed was real - Remove('probe') returned 1 and left task 1022 - but the cause is what the rework pass found: RemoveOne discarded %DeleteId's own %Status with a bare Do, and %DeleteId genuinely fails (ERROR #7415) when an id no longer resolves. Fixed there with a demonstrated mutation; guards now use a bare $Data(tIds) check with no subscript.
- 2026-09-10T21:46:27Z status=resolved-by:1-4-one-command-brings-up-an-instance-with-ocupilot-installed by=adjudication note=READ THIS BEFORE THE HEADING. This entry's own heading and evidence line state a mechanism that is DISPROVEN - they were written by me and the ledger grammar is append-only, so they cannot be rewritten. 0 '= "" is TRUE on this build; the real defect was %DeleteId's discarded %Status. Code review re-probed all five semantic claims live and confirmed the correction. Do not mine the heading.

### DW-54: iris_execute_tests appears to re-submit on client-side timeout, producing several concurrent server-side runs of the same class that race on shared fixtures and make latest-run attribution unreliable
- source: spec-1-4-one-command-brings-up-an-instance-with-ocupilot-installed.md | severity: med | fix-risk: med | footprint: in-epic
- evidence: One class-level call to iris_execute_tests returned 'Test execution timed out' client-side while at least five overlapping %UnitTest.Manager executions of OcuPilot.Test.Demo kept running server-side (run indices 234,240,241,243,+1), all calling OnBeforeAllTests->Fixture.Create against the same name-keyed %SYS.Task row. 241 passed, 234/240/243 failed with an identical 'the demo task opens' signature. This also undermines the %UnitTest_Result MAX(runIdx) probe this project treats as ground truth: the winning run is whichever sibling finished last.
- 2026-09-10T17:24:51Z status=routed owner=1-17-the-smoke-script-the-readiness-endpoint-and-ci by=cr note=affects every verification in the project, not just this story; 1.17 owns the smoke script and CI where a serialized, quiescence-checked runner belongs
- 2026-09-13T15:59:59Z status=resolved-by:1-17-the-smoke-script-the-readiness-endpoint-and-ci by=adjudication note=ui/tools/ci-runner.mjs runs one class per iris session invocation and confirms each in %UnitTest_Result by numeric run index before the next starts; measured 38 classes, 346 tests, 0 overlaps, 0 foreign runs

### DW-55: CLAUDE.md's Container block still documents the pre-Story-1.4 bring-up: bare docker compose up -d and 'ready when startup completes'
- source: spec-1-4-one-command-brings-up-an-instance-with-ocupilot-installed.md | severity: low | fix-risk: low | footprint: in-story
- evidence: CLAUDE.md:142-144 still reads 'docker compose up -d' and 'docker compose logs -f  # ready when startup completes', while README.md now uses 'docker compose up -d --wait' and explains that IRIS startup is no longer the readiness signal (the compose healthcheck is). The neighbouring 'Fresh container: expired password' section in the same file WAS updated by this story, so the file is internally inconsistent about its own bring-up. Not patched by code review: step-03 routes any fix that edits an agent-context file to the lead.
- 2026-09-10T21:44:29Z status=open owner=1-4-one-command-brings-up-an-instance-with-ocupilot-installed by=cr note=fold into the rework commit; agent-context file, lead-owned
- 2026-09-11T01:11:08Z occurrence=1-4-one-command-brings-up-an-instance-with-ocupilot-installed
- 2026-09-11T01:11:08Z by=cr note=also: the updated Fresh-container text now says unexpire is gated on the row's absence; code reads Phase=failed
- 2026-09-11T06:33:02Z status=resolved-by:1-4-one-command-brings-up-an-instance-with-ocupilot-installed by=adjudication note=lead-owned because step-03 routes agent-context edits away from the review stage. CLAUDE.md's Container block now uses 'docker compose up -d --wait', states that IRIS startup is no longer the readiness signal and that the health check is the contract, points logs at the iris service, and names the explicit 2026.2 pin. lint-docs clean.

### DW-56: Seven ACs (AC2, AC3, AC4, AC5, AC8, AC9, AC13) had their pinning tests added or materially changed by rework iteration 3 with no corresponding update…
- source: spec-1-4-one-command-brings-up-an-instance-with-ocupilot-installed.md | severity: low | fix-risk: low | footprint: in-story
- evidence: Verification Gap and Intent Alignment Auditor (2026-09-10 review, iteration 3 pass): each of these ACs' pinning test changed this pass (new tests, new assertions, or a corrected claim about what an existing assertion catches), but ## Verification's own mutation: line for that AC was not updated to …
- 2026-09-11T00:43:50Z status=open owner=1-4-one-command-brings-up-an-instance-with-ocupilot-installed by=harvest note=harvested at dev_complete rework iteration 3
- 2026-09-11T01:11:09Z occurrence=1-4-one-command-brings-up-an-instance-with-ocupilot-installed
- 2026-09-11T01:11:09Z by=cr note=AC3's mutation line is now wrong not just stale: pins TestFailingStepLeavesPhaseFailed which never calls StartPath
- 2026-09-11T19:38:29Z status=resolved-by:1-4-one-command-brings-up-an-instance-with-ocupilot-installed by=adjudication note=every AC carries a demonstrated mutation line in Verification, including round 3's six new pins folded in by the lead (5454643) and rework 8/cr4 pins

### DW-57: Fixture.RemoveOne's three status-checked Delete branches (webapp/sslconfig/x509credential, H3/M4) are exercised only on their success paths -- no com…
- source: spec-1-4-one-command-brings-up-an-instance-with-ocupilot-installed.md | severity: low | fix-risk: low | footprint: in-story
- evidence: Verification Gap (2026-09-10 review, iteration 3 pass): real gap, but lower priority than the two high-severity untested-regression gaps this same pass closed (H1's Uninstall-ordering test, M1's failed-first-install test) -- deferred rather than expanding this pass further. A failure-injection test…
- 2026-09-11T00:43:50Z status=open owner=1-4-one-command-brings-up-an-instance-with-ocupilot-installed by=harvest note=harvested at dev_complete rework iteration 3
- 2026-09-11T01:11:09Z occurrence=1-4-one-command-brings-up-an-instance-with-ocupilot-installed
- 2026-09-11T19:38:29Z status=resolved-by:1-4-one-command-brings-up-an-instance-with-ocupilot-installed by=adjudication note=RemoveOne's failure branches pinned (Verification DW-57 mutation run 380 and the three Delete branches); closure verified by cr round 3

### DW-58: Test/Demo.cls's date-scoped SYS.ApplicationError:ErrorList queries (TestDemoSeedsAnApplicationError and Fixture.CreateErrorEntry alike) can miss a re…
- source: spec-1-4-one-command-brings-up-an-instance-with-ocupilot-installed.md | severity: low | fix-risk: low | footprint: in-story
- evidence: Observed live (build-auto, 2026-09-10/11 review, iteration 3 pass): a full OcuPilot.Test.Demo class run failed TestDemoSeedsAnApplicationError with both of its ^ERRORS-derived assertions red, immediately after this session's own work crossed midnight (compile timestamps moved from 09/10 to 09/11) -…
- 2026-09-11T00:43:50Z status=open owner=1-4-one-command-brings-up-an-instance-with-ocupilot-installed by=harvest note=harvested at dev_complete rework iteration 3
- 2026-09-11T01:11:09Z occurrence=1-4-one-command-brings-up-an-instance-with-ocupilot-installed
- 2026-09-11T01:11:09Z by=cr note=same root cause found in the false-green direction; cr round 2 MED closes it by scoping the query to this run
- 2026-09-11T19:38:29Z status=resolved-by:1-4-one-command-brings-up-an-instance-with-ocupilot-installed by=adjudication note=closure verified at its site by cr round 3 (73a61f2); Test.Demo live run 608 9/9

### DW-59: The demo X.509 fixture bypasses %SYS.X509Credentials' own LoadCertificate path, so the credential lands with empty SubjectDN/IssuerDN/Thumbprint/SerialNumber/validity metadata and HasPrivateKey=0
- source: spec-1-4-one-command-brings-up-an-instance-with-ocupilot-installed.md | severity: med | fix-risk: high | footprint: in-story
- evidence: Fixture.CreateX509Credential sets Certificate and the [Transient] PrivateKey directly; irissys/%SYS/X509Credentials.cls documents SubjectKeyIdentifier, Thumbprint, SerialNumber, IssuerDN, SubjectDN and the validity dates as set only via LoadCertificate, with [Internal,Private] setters, and only LoadPrivateKey sets HasPrivateKey. AC9's observable (alias exists) holds; Story 6.3's non-empty Security lists would show a mostly-empty row. Needs a verified supported path from a checked-in PEM pair into those fields -- LoadCertificate reads a filesystem path, which AD-21 constrains -- so research, not a correction.
- 2026-09-11T01:11:19Z status=escalated owner=burndown by=cr note=Rule 15: MED with fix-risk high -> decision sheet. Same fixture as DW-49; decide together.
- 2026-09-13T18:42:36Z status=routed owner=burndown by=merge_gate note=owner decision 2026-09-13: same work as DW-49 and closed by the same change. Generating the pair at install and loading it through %SYS.X509Credentials.LoadCertificate populates SubjectDN, IssuerDN, Thumbprint, SerialNumber, validity and HasPrivateKey, which setting Certificate and the transient PrivateKey directly cannot. The open question is AD-21: LoadCertificate reads a filesystem path, so the generate-then-load path needs a route AD-21 permits, and that is what makes this research rather than a correction
- 2026-09-13T18:47:58Z status=wontfix-accepted by=merge_gate note=owner decision 2026-09-13: rides with DW-49. The empty SubjectDN/IssuerDN/Thumbprint/SerialNumber/validity and HasPrivateKey=0 are accepted for Release 1 because the fixture is a demo prop and AC9's observable - the alias exists - holds. Both close together in the generate-at-install story. reopen_if=Story 6.3's Security list is judged to read as broken with the mostly-empty row

### DW-60: GateStatus() does a full escalated SQL round trip (New $ROLES / AddRoles / %ExecDirect / %OpenId) on every API request, with no cache once the phase is terminal and no index on Version.Profile
- source: spec-1-4-one-command-brings-up-an-instance-with-ocupilot-installed.md | severity: med | fix-risk: med | footprint: out-of-footprint
- evidence: Installer.GateStatus is called from Api.Router.OnPreDispatch as the first act of every dispatch (AD-38). Harmless today -- no OcuPilot web application exists until Story 1.5 -- but it is on the hot path for every epic after this one, and the phase is terminal once installed.
- 2026-09-11T01:11:19Z status=routed owner=burndown by=cr note=No consumer traffic until 1.5; caching a terminal phase needs an invalidation story, so not a direct correction here.
- 2026-09-11T13:27:48Z occurrence=1-4-one-command-brings-up-an-instance-with-ocupilot-installed
- 2026-09-13T21:00:47Z status=routed owner=2-1-the-adminport-reproduces-the-vendor-s-dispatcher-exactly-onc by=burndown note=GateStatus runs a full escalated SQL round trip per API request with no cache once terminal. 2-1 builds the per-request AdminPort dispatch path whose latency this adds to
- 2026-09-14T02:47:21Z owner=2-1-the-adminport-reproduces-the-vendor-s-dispatcher-exactly-onc by=x0 note=excluded: med fix-risk; the gate call sits on 2.1's dispatcher path
- 2026-09-14T05:03:34Z status=wontfix-accepted by=spec_gate note=reopen_if=GateStatus() measures above 1 ms per call on a live instance (Story 2.1 plan measured 0.072 ms over 500 calls), or API p95 misses NFR-1 with the gate in the profile; a terminal-phase cache would miss another process's installing mark (AD-38)

### DW-61: The AC12/DW-58 fix's own tSinceSecsFloor (Fixture.CreateErrorEntry, and the independent copy in Test/Demo.cls TestDemoSeedsAnApplicationError) floors…
- source: spec-1-4-one-command-brings-up-an-instance-with-ocupilot-installed.md | severity: med | fix-risk: low | footprint: in-story
- evidence: Verified by code read (build-auto step-04 review pass, 2026-09-11; cited independently by Blind Hunter, Edge Case Hunter and Verification Gap in the same review): tSinceSecsFloor = (tSinceSecs \ 60) * 60 rounds DOWN to the start of pSinceH's own minute, so any entry timestamped at or after that min…
- 2026-09-11T04:00:26Z status=open owner=1-4-one-command-brings-up-an-instance-with-ocupilot-installed by=harvest note=harvested at dev_complete rework iteration 4
- 2026-09-11T04:02:03Z status=open owner=1-4-one-command-brings-up-an-instance-with-ocupilot-installed by=adjudication note=understated. This is not only a ~59s granularity window - as shipped, TestDemoSeedsAnApplicationError fails deterministically because CreateErrorEntry confirms at Create() time an entry the daemon has not produced yet. See DW-46's corrected diagnosis.
- 2026-09-11T07:35:33Z status=open owner=1-4-one-command-brings-up-an-instance-with-ocupilot-installed by=adjudication note=CORRECTION TO MY OWN 04:02 TRAILER. I attributed TestDemoSeedsAnApplicationError's red to CreateErrorEntry confirming at Create() time an entry the daemon had not produced. Superseded: rework iteration 5 moved the seed to a deterministic $$LOG^%ETN() entry that does not depend on the daemon, and it is green in run 314 (1.7s; HSCUSTOM error #15 at 07:07:16 reads <DIVIDE>SeedApplicationError+7^OcuPilot.Install.Fixture.1). AC12 is done. My mechanism may have been right for the old code, but I asserted it off an unverified premise - see DW-46.
- 2026-09-11T10:14:23Z status=resolved-by:1-4-one-command-brings-up-an-instance-with-ocupilot-installed by=adjudication note=closed. Superseded by the deterministic $$LOG^%ETN() error-log seed, which does not depend on the daemon; AC12 green in run 314 and confirmed through rework 5.

### DW-62: TestExistingApplicationIsNeverModified's new call to OcuPilot.Test.DemoAppProbe.Create('probe', ...) (this pass's own HIGH-finding fix) re-runs Fixtu…
- source: spec-1-4-one-command-brings-up-an-instance-with-ocupilot-installed.md | severity: med | fix-risk: low | footprint: in-story
- evidence: Verified by code read (build-auto step-04 review pass, 2026-09-11; cited independently by Blind Hunter, Edge Case Hunter and Verification Gap): Fixture.CreateTask's existing-task branch checks +tTask.Suspended > 0 and, if still 0, calls RunNow and waits up to TASKWAITSECONDS (300s) again, unconditi…
- 2026-09-11T04:00:26Z status=open owner=1-4-one-command-brings-up-an-instance-with-ocupilot-installed by=harvest note=harvested at dev_complete rework iteration 4
- 2026-09-11T19:38:29Z status=resolved-by:1-4-one-command-brings-up-an-instance-with-ocupilot-installed by=adjudication note=pOwnedByProfile fix finished in rework 5 per the owner's hand-off; closure verified by cr round 3; Test.Demo live run 608 9/9

### DW-63: Installer.IsEscalationInfrastructureAbsent -- this pass's own step-03 verify-stage fix for a real, live-discovered AC2 first-install ordering defect …
- source: spec-1-4-one-command-brings-up-an-instance-with-ocupilot-installed.md | severity: med | fix-risk: low | footprint: in-story
- evidence: Verified by code read and grep (build-auto step-04 review pass, 2026-09-11; cited independently by Verification Gap and the Intent Alignment Auditor): grep for IsEscalationInfrastructureAbsent across the tree finds it only in Installer.cls itself and this spec's own narrative -- no .cls test refere…
- 2026-09-11T04:00:26Z status=open owner=1-4-one-command-brings-up-an-instance-with-ocupilot-installed by=harvest note=harvested at dev_complete rework iteration 4
- 2026-09-11T19:38:29Z status=resolved-by:1-4-one-command-brings-up-an-instance-with-ocupilot-installed by=adjudication note=IsEscalationInfrastructureAbsent pinned (Verification DW-63 mutations); smoke14 first start logged 'genuinely first install' and installed; probe-only residual accepted as DW-78

### DW-64: AC3's 'the version row's phase is failed with the failing step named' cannot hold on a first install that fails before EnsureApplication. AC11's 'whe…
- source: spec-1-4-one-command-brings-up-an-instance-with-ocupilot-installed.md | severity: med | fix-risk: low | footprint: in-story
- evidence: Verified by code read and live (rework iteration 5, step-04 review; Blind Hunter, Edge Case Hunter and Intent Alignment Auditor independently). AC3. On a first install that fails before EnsureApplication, EnsureVersion's IsEscalationInfrastructureAbsent guard skips the read. The GuardedSave that fo…
- 2026-09-11T10:14:24Z status=open owner=1-4-one-command-brings-up-an-instance-with-ocupilot-installed by=harvest note=lead applied the Rule 5 amendment to AC3 and AC11 on 2026-09-11; resolve at adjudication
- 2026-09-11T10:14:39Z status=resolved-by:1-4-one-command-brings-up-an-instance-with-ocupilot-installed by=adjudication note=lead applied the Rule 5 apply-and-report amendments in the spec on 2026-09-11. AC3: where a version row can be recorded its phase is failed with the step named; before the protected DB exists the phase reads installing and the step is named in the hook log, still fail-safe. AC11: Suspended>0 within one Task Manager pass of install completing, the owner's accepted trade. Recorded in the Spec Change Log.

### DW-65: Installer.Uninstall ignores the inventory Fixture.Remove now keeps. After a failed fixture delete it still drops the OcuPilot* mapping and the OCUPIL…
- source: spec-1-4-one-command-brings-up-an-instance-with-ocupilot-installed.md | severity: med | fix-risk: med | footprint: in-story
- evidence: Verified by code read (Installer.cls Uninstall; Blind Hunter, Edge Case Hunter, Verification Gap and Intent Alignment Auditor). Uninstall calls Fixture.Remove and logs its warns. It then deletes the mapping and the database unconditionally. The orphaning itself predates this iteration: at baseline,…
- 2026-09-11T10:14:24Z status=open owner=1-4-one-command-brings-up-an-instance-with-ocupilot-installed by=harvest note=OWNER DECISION 2026-09-11: Uninstall stops before dropping the database while any fixture inventory row remains, reports what is left, exits non-zero
- 2026-09-11T19:38:29Z status=resolved-by:1-4-one-command-brings-up-an-instance-with-ocupilot-installed by=adjudication note=Uninstall refuses before dropping the database while inventory rows remain (owner decision); Test.UninstallGuard pins (mutation runs 482-484), live run 613 3/3; residuals DW-76, DW-77 accepted

### DW-66: With docker-compose.yml's pre-existing restart: unless-stopped, a deterministic install failure makes the container exit 1 and restart indefinitely, …
- source: spec-1-4-one-command-brings-up-an-instance-with-ocupilot-installed.md | severity: low | fix-risk: low | footprint: in-story
- evidence: Observed in the implement stage's AC3 throwaway runs. A failed StartPath makes iris-main shut IRIS down and exit 1; those runs used restart: 'no'. restart: unless-stopped has been in the compose file since the initial commit. For a transient failure the retry is harmless. For a deterministic failur…
- 2026-09-11T10:14:24Z status=open owner=1-4-one-command-brings-up-an-instance-with-ocupilot-installed by=harvest note=OWNER DECISION 2026-09-11: restart policy gets a retry limit (on-failure with max retries) so a deterministic install failure cannot loop
- 2026-09-11T19:38:29Z status=resolved-by:1-4-one-command-brings-up-an-instance-with-ocupilot-installed by=adjudication note=restart: on-failure:3 (owner decision); compose.test.mjs pin; throwaway showed four STARTPATH-FAILED attempts then stop (runB-docker.log); npm test 108/108

### DW-67: GatewayResponseTimeout's call into the corrected configuration-file fallback has no automated test. A regression that deleted that call would leave b…
- source: spec-1-4-one-command-brings-up-an-instance-with-ocupilot-installed.md | severity: med | fix-risk: low | footprint: in-story
- evidence: Verified by code read (Verification Gap). - The GatewayIni tests call GatewayTimeoutFromConfigFile and GatewayConfigFilePath directly. - On the long-lived instance the registry answers, so the real GatewayResponseTimeout never reaches the fallback call. - MigrateFault overrides the whole method. Th…
- 2026-09-11T10:14:24Z status=open owner=1-4-one-command-brings-up-an-instance-with-ocupilot-installed by=harvest note=harvested at dev_complete rework 5
- 2026-09-11T19:38:29Z status=resolved-by:1-4-one-command-brings-up-an-instance-with-ocupilot-installed by=adjudication note=GatewayResponseTimeout's config-file fallback call pinned (Verification DW-67 mutations, run 436); live run 602 3/3

### DW-68: The 'SYS.Database.DeleteDatabase takes 20-40 minutes' figure has no support in any %UnitTest record and matches the MCP runner's millisecond duration…
- source: spec-1-4-one-command-brings-up-an-instance-with-ocupilot-installed.md | severity: low | fix-risk: low | footprint: in-story
- evidence: Verified from %UnitTest_Result: - Records run from 2026-09-09 16:05, 374 runs at the time of checking. No uninstall method in them took longer than 2.51 s, and no OcuPilot.Test.Installer run longer than 64.4 s. - The MCP runner reports each method's duration in milliseconds. For one method it repor…
- 2026-09-11T10:14:24Z status=open owner=1-4-one-command-brings-up-an-instance-with-ocupilot-installed by=harvest note=lead corrected the false figure at all four origins on 2026-09-11 and added the units trap to objectscript-testing.md; resolve at adjudication
- 2026-09-11T10:14:39Z status=resolved-by:1-4-one-command-brings-up-an-instance-with-ocupilot-installed by=adjudication note=lead corrected the false figure at every origin on 2026-09-11: the Story 1.4 frozen Boundaries line, the lead's own cycling-budget paragraph, Story 1.3's spec (latency half only; its <PROTECT> half stands, unrefuted), and epic-1-context.md. Added three result-reading traps to .claude/rules/objectscript-testing.md, the first being the ms-vs-seconds mismatch.

### DW-69: The two new .claude/rules/objectscript-basics.md bullets are slightly imprecise. Dropping one OREF forces a fresh read only if that was the last refe…
- source: spec-1-4-one-command-brings-up-an-instance-with-ocupilot-installed.md | severity: low | fix-risk: low | footprint: in-story
- evidence: Blind Hunter review, consistent with irislib/%Library/Persistent.cls's %Open. This is an agent-context file, so it is routed to the lead rather than patched in review. [loc: .claude/rules/objectscript-basics.md ('Collections and object identity')]
- 2026-09-11T10:14:24Z status=open owner=1-4-one-command-brings-up-an-instance-with-ocupilot-installed by=harvest note=the rework-5 agent wrote these bullets; tighten them in the next pass
- 2026-09-11T12:07:01Z status=resolved-by:1-4-one-command-brings-up-an-instance-with-ocupilot-installed by=adjudication note=lead finished it. Rework 6 rewrote the two bullets and left two imprecisions, which the lead corrected after checking irislib/%Library/Persistent.cls directly: a concurrency 3/4 lock is also released when concurrency is lowered below 3 (%DowngradeConcurrency calls %ReleaseLock and keeps the object) - now stated, with a caution that the method is Internal so application code should drop the reference instead; and %Reload() necessarily keeps the reference across the wait, so the closing 'hold no reference' advice now applies only to the re-open form.
- 2026-09-11T13:27:48Z occurrence=1-4-one-command-brings-up-an-instance-with-ocupilot-installed
- 2026-09-11T13:27:48Z by=cr note=the lock bullet's heading still says 'for the object's life' while its body gives a second release path

### DW-70: The party-mode memlog's 2026-09-11T00:30 entry (local time, no zone) still says AC11's test passes only via its SKIP branch, and no later line record…
- source: spec-1-4-one-command-brings-up-an-instance-with-ocupilot-installed.md | severity: low | fix-risk: low | footprint: in-story
- evidence: _bmad-output/party-mode/memories/installed/.memlog.md. The entry was true at its timestamp. Runs 320 onward superseded it: the task test now observes a suspended task and has no skip branch. This is an agent-context file, so it is routed to the lead. [loc: _bmad-output/party-mode/memories/installed…
- 2026-09-11T10:14:24Z status=open owner=1-4-one-command-brings-up-an-instance-with-ocupilot-installed by=harvest note=owner party-mode session memory; accurate when written
- 2026-09-11T10:14:39Z status=by-design by=adjudication note=the owner's party-mode session memory was accurate when written at 00:30 local; the SKIP branch it describes has since been deleted. A dated session log is a record of that moment, not a claim to correct.

### DW-71: CLAUDE.md's Container block did not tell agents what restart: on-failure:3 means: a failed install stops after three restarts, and per Docker docs the container is not restarted after a reboot
- source: spec-1-4-one-command-brings-up-an-instance-with-ocupilot-installed.md | severity: low | fix-risk: low | footprint: in-story
- evidence: DW-66 changed docker-compose.yml's restart policy; README's bring-up section documented it but the agent-facing Container block in CLAUDE.md did not, and the live container still runs unless-stopped until recreated. Deferred to the lead by rework 6 because CLAUDE.md is agent-context.
- 2026-09-11T12:07:01Z status=open owner=1-4-one-command-brings-up-an-instance-with-ocupilot-installed by=harvest note=lead-owned
- 2026-09-11T12:07:01Z status=resolved-by:1-4-one-command-brings-up-an-instance-with-ocupilot-installed by=adjudication note=lead added it to CLAUDE.md's Container block, keeping README's attribution of the reboot behavior to Docker's documentation rather than claiming it was observed, and stating that the live container keeps unless-stopped until recreated and must not be recreated just to pick up the new policy.

### DW-72: No start-scoped installing signal: on a same-version restart the gate and the health check read the previous start's installed row while the hook recompiles and re-installs
- source: spec-1-4-one-command-brings-up-an-instance-with-ocupilot-installed.md | severity: med | fix-risk: high | footprint: in-epic
- evidence: Nothing writes Phase=installing; EnsureVersion runs only after the Try (Installer.cls). container-start.sh runs LoadDir before StartPath, and the health check reads GateStatus(), so on a repeat start --wait can return healthy before this start's install ran, even when it then fails (AC3 'never reports healthy' holds only on first start/upgrade). The API gate serves during the recompile window once 1.5's apps exist. Blind Hunter + Edge Case Hunter + Acceptance Auditor, cr round 3.
- 2026-09-11T13:26:52Z status=escalated owner=burndown by=cr note=decision sheet; AD-38 reading (arch weight); rounds 1-2 rejected it as low; fix spans hook, health check, 1.17 readiness
- 2026-09-11T14:51:18Z status=open owner=1-4-one-command-brings-up-an-instance-with-ocupilot-installed by=lead note=OWNER DECISION 2026-09-11: accept lead recommendation; mark installed->installing before each start recompiles and make the health check start-scoped; AD-38 amended; rework 8
- 2026-09-11T19:38:29Z status=resolved-by:1-4-one-command-brings-up-an-instance-with-ocupilot-installed by=adjudication note=MarkInstalling before LoadDir plus a start-scoped health marker (AD-38 as amended); InstallMark pins (live run 612 6/6); throwaway: reverted check went healthy 16 s before STARTPATH-OK (implement-8), smoke14 restart first healthy probe after STARTPATH-OK

### DW-73: EnsureUnexpired runs inside Install(), which AD-17 makes the IPM <Invoke> entry too, so a first IPM install unexpires a _SYSTEM an operator deliberately left expired
- source: spec-1-4-one-command-brings-up-an-instance-with-ocupilot-installed.md | severity: med | fix-risk: med | footprint: in-epic
- evidence: The unexpire call sits in Install() (Installer.cls), gated only on 'first OcuPilot install' for the profile; AD-17 says 'unexpires _SYSTEM where that is needed, so a fresh Community container' can be used. Live once Story 1.16 ships the IPM path. Blind Hunter + Acceptance Auditor, cr round 3.
- 2026-09-11T13:26:52Z status=decision-pending owner=burndown by=cr note=product/security call; recommend confining the unexpire to StartPath before 1.16; mirror into spine Deferred
- 2026-09-11T14:51:18Z status=open owner=1-4-one-command-brings-up-an-instance-with-ocupilot-installed by=lead note=OWNER DECISION 2026-09-11: accept lead recommendation; unexpire _SYSTEM from the container start path only, never the IPM entry; AD-17 amended; rework 8
- 2026-09-11T19:38:29Z status=resolved-by:1-4-one-command-brings-up-an-instance-with-ocupilot-installed by=adjudication note=Install(pProfile, pUnexpire=0), only StartPath passes 1 (AD-17 as amended); UnexpireScope pins, live run 611 5/5; lead mutation run 595 red, 596 green; smoke14 fresh start unexpired _SYSTEM (ChangePassword 0)

### DW-74: AD-25's Rule names /csp/myapp literally yet requires the fixture to be 'namespaced so it cannot collide'; the spec's behavioural reading lives only in the spec, not the spine
- source: spec-1-4-one-command-brings-up-an-instance-with-ocupilot-installed.md | severity: med | fix-risk: low | footprint: in-epic
- evidence: Design Notes (DW-13) read 'namespaced' as behaviour for the one literal path (never modify, enable, grant or inventory an app install did not create); the code complies (CreateWebApp collision branch, pinned). Rule 20 requires a decision with architectural weight in the spine; AD-25's text is unchanged. Acceptance Auditor, cr round 3.
- 2026-09-11T13:26:52Z status=open owner=1-4-one-command-brings-up-an-instance-with-ocupilot-installed by=cr note=lead: Rule 20 amendment of AD-25's Rule to the behavioural reading; no code change
- 2026-09-11T14:51:18Z status=resolved-by:1-4-one-command-brings-up-an-instance-with-ocupilot-installed by=lead note=AD-25 Rule amended with the behavioral reading of namespaced (Rule 20, memlog entry 51); no code change

### DW-75: CLAUDE.md's Container and expired-password text is wrong in four places, one of which makes its start command recreate the live ocupilot container
- source: spec-1-4-one-command-brings-up-an-instance-with-ocupilot-installed.md | severity: med | fix-risk: low | footprint: in-story
- evidence: docker inspect ocupilot (2026-09-11): image latest-cd, restart unless-stopped, no healthcheck, no command, no mounts, no OCUPILOT_DEMO -- so 'docker compose up -d --wait' recreates it (config hash changed), running StartPath(1) on the live volume. Also: 'the health check runs OcuPilot's own install' (the hook does); restart count 'resets only on up' (docker start also resets); unexpire 'gated on the version row's absence' (absent or failed-at-schema-0).
- 2026-09-11T13:26:52Z status=open owner=1-4-one-command-brings-up-an-instance-with-ocupilot-installed by=cr note=agent-context file, lead-owned: fix the four statements; warn that up -d --wait recreates the pre-1.4 live container
- 2026-09-11T18:18:03Z status=resolved-by:1-4-one-command-brings-up-an-instance-with-ocupilot-installed by=lead note=CLAUDE.md Container block rewritten (5454643): live-container recreate warning first, the hook (not the health check) runs install, restart count wording, first-install gate; health and unexpire sentences updated after DW-72/DW-73 landed (ee09465)

### DW-76: Uninstall's carve-out for a missing OcuPilotState cannot tell a completed uninstall from the application deleted by hand, and in the second case drops the database with inventory rows still in it
- source: spec-1-4-one-command-brings-up-an-instance-with-ocupilot-installed.md | severity: low | fix-risk: med | footprint: in-story
- evidence: Installer.Uninstall carries on when RemainingDemoFixtures fails and Base.#APPLICATION is absent, without checking that the OCUPILOT database is gone; if OcuPilotState was deleted by hand while fixtures were recorded, the rows are dropped and the objects orphaned (the owner's DW-65 rule). Reachable only by hand-deleting OcuPilot's privileged app on a demo-flag install. Flagged by rework 6; judged in cr round 3.
- 2026-09-11T13:27:11Z status=wontfix-accepted owner=1-4-one-command-brings-up-an-instance-with-ocupilot-installed by=cr note=reopen_if=Uninstall logs 'application no longer exists' while Config.Databases.Exists('OCUPILOT')=1; fix: also require that DB gone
- 2026-09-11T13:27:24Z status=wontfix-accepted owner=1-4-one-command-brings-up-an-instance-with-ocupilot-installed by=cr note=reopen_if=Uninstall logs 'application no longer exists' while the OCUPILOT database still exists

### DW-77: A production Uninstall checks only the production profile's inventory rows, then drops the database that also holds every other profile's rows
- source: spec-1-4-one-command-brings-up-an-instance-with-ocupilot-installed.md | severity: low | fix-risk: med | footprint: in-story
- evidence: Remaining('') reads Profile IS NULL rows only; a probe run's rows live in the same OCUPILOT database, so their OcuPilotDemoProbe* objects would be orphaned. Probe rows exist only during or after an interrupted test run. Blind Hunter + Edge Case Hunter, cr round 3; Uninstall's header now says so.
- 2026-09-11T13:27:11Z status=wontfix-accepted owner=1-4-one-command-brings-up-an-instance-with-ocupilot-installed by=cr note=reopen_if=a third profile is supported, or Demo rows with Profile IS NOT NULL exist outside a test run

### DW-78: IsEscalationInfrastructureAbsent checks the profile's own privileged application, but every profile's version row escalates through OcuPilotState
- source: spec-1-4-one-command-brings-up-an-instance-with-ocupilot-installed.md | severity: low | fix-risk: low | footprint: in-story
- evidence: Names('probe') gives OcuPilotStateProbe; Version/Demo/Stamp reads use Base.#APPLICATION. After a probe uninstall every probe install logs a false 'genuinely first install' and skips the read, so a stale probe row is ignored (downgrade refusal bypassed, duplicate row) and Test.Version's downgrade test passes only once the probe app exists. Probe-only; production names match.
- 2026-09-11T13:27:11Z status=wontfix-accepted owner=1-4-one-command-brings-up-an-instance-with-ocupilot-installed by=cr note=reopen_if=a probe row survives Uninstall('probe') and the next Install('probe') writes a second row or skips a refusal
- 2026-09-11T19:26:37Z occurrence=1-4-one-command-brings-up-an-instance-with-ocupilot-installed
- 2026-09-11T19:26:37Z by=cr note=cr round 4: MarkInstalling repeats the probe-only application check; its comment now says so and cites DW-78

### DW-79: Every probe install after a probe uninstall reaches the real UnExpireUserPasswords('_SYSTEM') on the shared instance
- source: spec-1-4-one-command-brings-up-an-instance-with-ocupilot-installed.md | severity: low | fix-risk: med | footprint: in-story
- evidence: tFirstInstall is per profile but _SYSTEM is instance-wide; Test.Installer's install/uninstall cycles, TestFirstInstallFlagComesFromTheVersionRow and Escalation.RepairProbeVersionRow all install the probe with no row, and InstallerProbe.EnsureUnexpired delegates to super. Idempotent here; undoes a deliberate expiry on any instance that runs the suite. Blind Hunter + Edge Case Hunter + Acceptance Auditor, cr round 3.
- 2026-09-11T13:27:11Z status=wontfix-accepted owner=1-4-one-command-brings-up-an-instance-with-ocupilot-installed by=cr note=reopen_if=_SYSTEM reads ChangePassword=1 before a suite run on any instance the suite is run against
- 2026-09-11T14:51:18Z occurrence=1-4-one-command-brings-up-an-instance-with-ocupilot-installed
- 2026-09-11T14:51:18Z by=lead note=expected to fall out of DW-73 (suite installs the probe through Install, which will no longer unexpire); rework 8 confirms or names the remaining caller
- 2026-09-11T19:38:29Z status=resolved-by:1-4-one-command-brings-up-an-instance-with-ocupilot-installed by=adjudication note=fell out of DW-73: probe installs go through Install() with pUnexpire=0; the one real-unexpire test now uses the UnexpireReal seam (cr4)

### DW-80: Uninstall never removes the application-error entries the demo fixture seeds, and the inventory records a label, not their ids
- source: spec-1-4-one-command-brings-up-an-instance-with-ocupilot-installed.md | severity: low | fix-risk: med | footprint: in-story
- evidence: RemoveOne's errorentry branch removes nothing by design (Fixture.cls: the Logs area's own delete owns ^ERRORS, AD-48); CreateErrorEntry seeds one entry per start and NoteRow records 'OcuPilotDemo application error'. The Intent says uninstall removes exactly what install created. Demo-flag installs only. Acceptance Auditor, cr round 3.
- 2026-09-11T13:27:37Z status=wontfix-accepted owner=1-4-one-command-brings-up-an-instance-with-ocupilot-installed by=cr note=reopen_if=seeding reaches a non-demo path, or Story 13.1 requires no OcuPilotDemo seed entries after uninstall

### DW-81: Uninstall deletes fixture objects by recorded name, so an operator's own object that later took a deleted fixture's name is removed
- source: spec-1-4-one-command-brings-up-an-instance-with-ocupilot-installed.md | severity: low | fix-risk: med | footprint: in-story
- evidence: RemoveOne deletes whatever holds the recorded name (webapp, SSL/TLS, X.509, task) with no marker check; if an operator deleted the demo fixture and created their own /csp/myapp, Uninstall would delete theirs. Fixtures exist only under the opt-in flag, set only by this repository's compose file (AD-25). Edge Case Hunter, cr round 3.
- 2026-09-11T13:27:37Z status=wontfix-accepted owner=1-4-one-command-brings-up-an-instance-with-ocupilot-installed by=cr note=reopen_if=OCUPILOT_DEMO can be set on any install path other than this repository's docker-compose.yml

### DW-82: Four tests mutate shared production state and repair it only if the process survives; an interrupted downgrade test leaves a row that makes the next start refuse
- source: spec-1-4-one-command-brings-up-an-instance-with-ocupilot-installed.md | severity: low | fix-risk: med | footprint: in-story
- evidence: TestStartPathPropagatesAFailingStep (row failed), TestGateStatusIsNotInstalledWhenStoredVersionIsAheadOfDeployed (SchemaVersion inflated), TestVersionDeleteByProfileRemovesTheProductionRow and Demo.TestDeleteByProfileRemovesProductionNullRows (rows deleted) restore in Try/Catch only. A killed job mid-window leaves production failed or ahead. Blind Hunter, cr round 3; Test.GateLadderRow now offers a no-write route.
- 2026-09-11T13:27:37Z status=wontfix-accepted owner=1-4-one-command-brings-up-an-instance-with-ocupilot-installed by=cr note=reopen_if=after a test run GateStatus() is not installed or the production row's SchemaVersion is not 1

### DW-83: The live ocupilot instance carries a stale mount of the probe database directory (/durable/iris/mgr/ocupilotprobe/, SFN 14, no IRIS.DAT, no config entry), so every probe install there fails at EnsureDatabase
- source: spec-1-4-one-command-brings-up-an-instance-with-ocupilot-installed.md | severity: med | fix-risk: low | footprint: out-of-footprint
- evidence: Caused by rework 8's implement stage running 18 test classes concurrently (runs 539-556 overlapped 15:47:04-15:47:34, lead-verified in %UnitTest_Result.TestInstance); a probe Uninstall raced a probe Install. Lead-verified: SYS.Database reads Mounted=1 SFN=14, no directory; DismountDatabase <PROTECT>Dismount+6^SYS.Database.1 even after recreating %DB_OCUPILOTPROBE (reverted). Blocks 7 test classes on the live instance.
- 2026-09-11T16:16:55Z status=decision-pending owner=burndown by=harvest note=human=owner authorizes a restart of the live ocupilot IRIS (inference, unverified: a restart clears it, as for Story 1.3's Delete+9)
- 2026-09-11T18:15:21Z status=resolved-by:1-4-one-command-brings-up-an-instance-with-ocupilot-installed by=lead note=owner-authorized docker restart -t 120 ocupilot at 18:14:36Z (handoff-story-1-4-close-2026-09-11.md item 2); after it SYS.Database.%OpenId(probe dir) = ERROR #6046 does not exist; production gate installed

### DW-84: Uninstall takes no install lock, so an Install and an Uninstall of one profile can overlap -- the overlap that left the live instance's probe database mounted with no file
- source: spec-1-4-one-command-brings-up-an-instance-with-ocupilot-installed.md | severity: med | fix-risk: low | footprint: in-story
- evidence: Rework 8 put DW-47's lock on Install and MarkInstalling only (Installer.cls LockInstall); Uninstall never calls it. Two concurrent test classes, one uninstalling and one installing the probe profile, produced the stale SFN 14 mount at 15:47:33 (messages.log per the implement stage; overlap lead-verified).
- 2026-09-11T16:16:55Z status=open owner=1-4-one-command-brings-up-an-instance-with-ocupilot-installed by=harvest note=fix-now under Rule 15; rework 8 continued: Uninstall takes the same lock, pinned with a second process
- 2026-09-11T19:38:29Z status=resolved-by:1-4-one-command-brings-up-an-instance-with-ocupilot-installed by=adjudication note=Uninstall holds the install lock; TestUninstallRefusesWhileTheLockIsHeld and TestInstallAndMarkRefuseWhileAnUninstallRuns (live run 614 6/6; mutations t9 run 9, cr4 run 11)

### DW-85: Test.Installer.TestGrantForRealAccountGrantsAndAudits fails on a genuinely fresh instance's first class run and cannot go red on the long-lived one
- source: spec-1-4-one-command-brings-up-an-instance-with-ocupilot-installed.md | severity: low | fix-risk: low | footprint: in-story
- evidence: Throwaway ocupilot-t8b (rework 8): first Test.Installer run 22/23 with only this assertion red, a second run 23/23; on the long-lived instance earlier runs' audit rows always satisfy the count. Story 1.17's CI runs on a fresh container.
- 2026-09-11T16:16:55Z status=open owner=1-4-one-command-brings-up-an-instance-with-ocupilot-installed by=harvest note=LOW two-way door: make the count see this run's own rows and able to fail (Rule 19), or show why it cannot
- 2026-09-11T19:38:29Z status=resolved-by:1-4-one-command-brings-up-an-instance-with-ocupilot-installed by=adjudication note=the count reads unindexed audit data over the install window (%SYS.Audit index lag, not process visibility); first run on a fresh instance 23/23 three times (t9 run 2, t9r run 1, smoke14 run 2); mutation t9 run 11 red

### DW-86: Story 1.3's spec stated the wrong audit-visibility mechanism (a same-process read-visibility artifact) at its origin; DW-85 showed it is the lag of %SYS.Audit's indexes
- source: spec-1-4-one-command-brings-up-an-instance-with-ocupilot-installed.md | severity: low | fix-risk: low | footprint: in-epic
- evidence: Blind Hunter, rework 8 step-04: spec-1-3 lines 181 and 310 carried it; DW-85's fresh-throwaway probe saw the row in ^IRIS.AuditD at once and the indexed count catch up about 60 s later (UpdateIndices).
- 2026-09-11T18:15:59Z status=resolved-by:1-4-one-command-brings-up-an-instance-with-ocupilot-installed owner=1-4-one-command-brings-up-an-instance-with-ocupilot-installed by=harvest note=lead corrected both sites in spec-1-3 at origin with a marked note, 2026-09-11

### DW-87: Fix Pack F-1's production half (a completed production Uninstall logs no false purge warns) has no committed test; seen only on throwaway containers
- source: spec-1-4-one-command-brings-up-an-instance-with-ocupilot-installed.md | severity: low | fix-risk: med | footprint: in-story
- evidence: Verification Gap + Intent Alignment, rework 8 step-04: every Uninstall in src/OcuPilot/Test passes probe; removing the If pProfile '= "" guard leaves the suite green. A committed test would uninstall production, which the shared instance forbids.
- 2026-09-11T18:15:59Z status=wontfix-accepted owner=1-4-one-command-brings-up-an-instance-with-ocupilot-installed by=harvest note=reopen_if=Story 1.17's scripted throwaway run (DW-50) logs a could-not-purge warn on a completed production Uninstall

### DW-88: CLAUDE.md's rework-8 Container block is wrong in three places: the mark is said to stop the API serving an earlier stamp, failures to name a step, and only up to be unsafe
- source: spec-1-4-one-command-brings-up-an-instance-with-ocupilot-installed.md | severity: med | fix-risk: low | footprint: in-epic
- evidence: Code review round 4 (Blind Hunter, Edge Case Hunter, Acceptance Auditor): :161-162 'never reads healthy, or serves the API, on an earlier start's stamp' -- the hook runs after IRIS serves and the mark is skipped or fails on NOCLASS/NOMETHOD/FAILED, and 'never healthy' comes from the start marker; :172-173 LOAD-FAILED, no-marker and lock/downgrade refusals name no step; :141-148 docker compose down removes the pre-1.4 container (only a recreating up brings it back), exec changes state (the file's own unexpire recovery), restart is the owner's call too.
- 2026-09-11T19:26:06Z status=escalated owner=burndown by=cr note=agent-context, lead-owned: correct the three statements in CLAUDE.md's Container block (cr round 4)
- 2026-09-11T19:34:05Z status=resolved-by:1-4-one-command-brings-up-an-instance-with-ocupilot-installed by=lead note=CLAUDE.md corrected at origin: start-scoped check (not the mark) keeps health honest, the mark is best effort; logs say why per outcome, refusals name no step; down is unsafe too, restart is the owner's call, exec is not read-only

### DW-89: The 2026-09-11 amendments of AD-38 and AD-17 state more than the code and the owner's decisions: every start marks, and unexpire only once per durable volume
- source: spec-1-4-one-command-brings-up-an-instance-with-ocupilot-installed.md | severity: med | fix-risk: low | footprint: in-epic
- evidence: Code review round 4 (Blind Hunter, Acceptance Auditor, Edge Case Hunter): AD-38 says each start marks an installed stamp before it recompiles and names only failed/absent stamps as left alone; the hook skips the mark on NOCLASS/NOMETHOD and carries on when it fails or is refused (DW-72 constraint 2), and leaves an installing stamp too. AD-17 says unexpire only on a genuinely first install on that durable volume; per AC14 the code unexpires whenever the profile has no version row or a failed-at-0 one, so again after a production Uninstall.
- 2026-09-11T19:26:12Z status=escalated owner=burndown by=cr note=lead, Rule 20: amend AD-38 (the mark is best effort; installing left) and AD-17 (first = AC14's no-row) (cr round 4)
- 2026-09-11T19:34:05Z status=resolved-by:1-4-one-command-brings-up-an-instance-with-ocupilot-installed by=lead note=Rule 20: AD-38 now says the health check is the guarantee and the mark is best effort (failed, installing, absent left); AD-17's first install is AC14's no-row-or-failed-at-0; memlog entry 52, lint ok

### DW-90: The testing rule's new 'Never run two test classes at once' section says to send the next class once a call returns, but a returned client-side timeout leaves the run going
- source: spec-1-4-one-command-brings-up-an-instance-with-ocupilot-installed.md | severity: med | fix-risk: low | footprint: in-epic
- evidence: Code review round 4 (Blind Hunter): .claude/rules/objectscript-testing.md:130 'wait for it to return, then send the next'; the same file's trap (line ~152) says the runner can return 'Test execution timed out' while the run keeps going server-side. Read literally, the new line sends the next class into a run still in flight -- the probe install/uninstall overlap behind DW-83. The section gives no way to see a run in flight.
- 2026-09-11T19:26:18Z status=escalated owner=burndown by=cr note=rules file, lead-owned: wait until the run has landed in %UnitTest_Result, and say how to see one in flight (cr round 4)
- 2026-09-11T19:34:05Z status=resolved-by:1-4-one-command-brings-up-an-instance-with-ocupilot-installed by=lead note=rules file corrected: send the next class only once the run has landed in %UnitTest_Result; an unlanded run is an empty-DateTime zero-Duration TestInstance row; confirm no process runs it before calling it abandoned

### DW-91: No pin can see Uninstall release its install lock after fixture removal but before its database delete, or MarkInstalling release it before its row write
- source: spec-1-4-one-command-brings-up-an-instance-with-ocupilot-installed.md | severity: low | fix-risk: med | footprint: in-story
- evidence: Code review round 4 (Blind Hunter, Verification Gap): LockPause pauses an uninstall in RemoveDemoFixtures, before the %SYS delete block, and has no seam inside the delete block or inside MarkInstalling; moving either unlock earlier keeps InstallLock green. Install's half was patched in cr round 4 (the pause now follows EnsureVersion; early release red, throwaway run 9). A pin needs a production seam inside Uninstall's delete block.
- 2026-09-11T19:26:25Z status=wontfix-accepted owner=1-4-one-command-brings-up-an-instance-with-ocupilot-installed by=cr note=reopen_if=Uninstall's or MarkInstalling's UnlockInstall moves above its last write, or a probe DB is again mounted with no IRIS.DAT

### DW-92: Story 1.16's IPM <Invoke> must call Install() with no second argument, never StartPath, or an IPM install unexpires _SYSTEM again (AD-17, DW-73)
- source: spec-1-4-one-command-brings-up-an-instance-with-ocupilot-installed.md | severity: low | fix-risk: low | footprint: in-epic
- evidence: Code review round 4 (Blind Hunter): DW-73 made the unexpire step reachable only through Install's pUnexpire, which only StartPath sets; the IPM half therefore rests on a manifest that does not exist yet. epics.md's Story 1.16 says only 'the installer invoke'. AD-17 binds it; nothing puts it in 1.16's plan inbox.
- 2026-09-11T19:26:30Z status=routed owner=1-16-the-ipm-module-generated-from-one-roster by=cr note=1.16 plan inbox: <Invoke> calls Install() only; pin that an IPM install never reaches EnsureUnexpired (cr round 4)
- 2026-09-11T19:34:05Z by=lead note=Rule 17 1b: line added under Story 1.16's routed list in epics.md
- 2026-09-13T08:23:41Z status=resolved-by:1-16-the-ipm-module-generated-from-one-roster by=adjudication note=closed structurally: the bundle moves by FileCopy so the IPM Invoke stays literally argument-free and pUnexpire keeps its 0 default. Pinned live on a throwaway with no start hook by asserting _SYSTEM is STILL expired after an IPM install

### DW-93: The client half of the deep-link criterion has no executed test host: the router wiring, the route table and the DeepLink component are pinned only by a manual browser check
- source: spec-1-5-the-static-shell-serves-the-spa-including-deep-links.md | severity: med | fix-risk: med | footprint: in-story
- evidence: ui/package.json's test script runs node --test tools/ only; angular.json declares no test target and no .spec.ts exists. Dropping provideRouter from main.ts leaves npm --prefix ui test and every ObjectScript suite green. Closing it means standing up a client test runner (ng test / vitest).
- 2026-09-12T00:34:51Z status=open owner=1-5-the-static-shell-serves-the-spa-including-deep-links by=harvest note=AC3/AC5 client half rests on the lead's manual browser check; adjudicate against delivered scope at this story's gate
- 2026-09-12T01:28:13Z occurrence=1-5-the-static-shell-serves-the-spa-including-deep-links
- 2026-09-12T01:32:13Z status=routed owner=1-9-the-screen-descriptor-registry-and-privilege-driven-navigati by=adjudication note=not closed by delivered scope: QA added no client runner by instruction. 1.9 rewrites app.routes.ts and the deep-link placeholder, so its gate is the first that fails while the client has no executed test host
- 2026-09-12T07:17:39Z occurrence=1-7-sign-out
- 2026-09-12T13:45:10Z status=resolved-by:1-9-the-screen-descriptor-registry-and-privilege-driven-navigati by=adjudication note=closed after three deferrals: @angular/build:unit-test on vitest with jsdom landed, and the shell now has executed component tests (app.routes, rail, rail-wire, screen-outlet, side-bar). Rendered DOM, ARIA state and focus are falsifiable for the first time

### DW-94: Install adopts and repairs whatever web application sits at /ocupilot or /api/ocupilot with no check that install created it, and Uninstall then deletes it
- source: spec-1-5-the-static-shell-serves-the-spa-including-deep-links.md | severity: med | fix-risk: med | footprint: in-story
- evidence: EnsureWebApplication branches on Security.Applications.Exists(pName) alone, so a pre-existing application at either path is rewritten to OcuPilot's dispatch class, auth bit, matching role and path, and removed by Uninstall. Boundaries say repair only what install created; AC12 requires repeat install to repair drift at those paths. Install has no provenance record for these two objects.
- 2026-09-12T00:34:51Z status=decision-pending owner=burndown by=harvest note=product call: adopt-and-repair vs refuse-a-foreign-application. Uninstall deleting an application OcuPilot did not create is destructive on an operator instance. For the epic decision sheet.
- 2026-09-12T01:28:13Z occurrence=1-5-the-static-shell-serves-the-spa-including-deep-links
- 2026-09-12T03:13:51Z status=routed owner=1-17-the-smoke-script-the-readiness-endpoint-and-ci by=checkin note=owner decided 2026-09-11: refuse a foreign application at those paths, report the conflict, uninstall only what install created. 1.17 adds the third application through the same path and needs the provenance record
- 2026-09-13T15:59:59Z status=resolved-by:1-17-the-smoke-script-the-readiness-endpoint-and-ci by=adjudication note=OcuPilot.Kernel.State.WebApp makes install-created a fact on the instance; install refuses a foreign application at any roster path and uninstall removes only what it created. Owner decision 2026-09-11 was refuse-a-foreign-application. Residual: the acceptance text still states the superseded refuse-on-missing-provenance contract, owned by DW-220

### DW-95: Api.StaticHandler writes file bytes to the response device, which AD-12's Rule reserves for the one response writer; the spec grants the carve-out but the spine was never amended
- source: spec-1-5-the-static-shell-serves-the-spa-including-deep-links.md | severity: med | fix-risk: high | footprint: out-of-footprint
- evidence: StaticHandler.StreamToDevice calls pStream.OutputToDevice; AD-12 says the response writer is the only code in the tree permitted to write to the response device. The spec's Boundaries say 'the static handler writes file bytes only', and the Spec Change Log records AD-21/AD-45/AD-13 amended for this story but not AD-12. Only the lead amends the spine (Rule 20).
- 2026-09-12T01:28:23Z status=escalated owner=burndown by=cr note=recommend amending AD-12's Rule to except a stream of static file bytes from a dispatch class that writes no envelope; code needs no change
- 2026-09-12T03:13:51Z status=by-design by=checkin note=owner decided 2026-09-11: AD-12 amended with the static-handler carve-out (file bytes only; every static failure still renders through Error.Render). Code unchanged, spine now matches it

### DW-96: The SQL grant EnsureSqlPrivileges makes is install-created state that neither StateFingerprint nor AnyObjectExists covers, and its schema name is hand-transcribed
- source: spec-1-5-the-static-shell-serves-the-spa-including-deep-links.md | severity: med | fix-risk: high | footprint: out-of-footprint
- evidence: EnsureSqlPrivileges GRANTs OcuPilot_Kernel_State to the DBRESOURCE role on every install; StateFingerprint folds the two applications and the shell role but not the grant, so a revoked or widened grant leaves the fingerprint byte-identical while the install gate answers INSTALL.INSTALLING to every non-%All caller -- the live defect this step was added to fix. tSchema is a literal derived from nothing and pinned by nothing.
- 2026-09-12T01:28:23Z status=escalated owner=burndown by=cr note=fix-risk high: reading a SQL grant inside StateFingerprint's switched-namespace window needs its own failure sentinel; decide the shape at the decision sheet
- 2026-09-13T18:47:58Z status=routed owner=burndown by=merge_gate note=owner decision 2026-09-13, and a better design than the sheet's recommendation. Do NOT fold the grant into StateFingerprint - that adds a second SQL round trip per request (worsening DW-60) and reports drift opaquely. Instead stop discarding the cause: GateStatus:1256's Catch maps EVERY read failure to installing, so a PROTECT from the missing grant is indistinguishable from an unfinished install. Give an unreadable-state failure its own named state, read the grant back at install so one that did not take fails loudly there, and derive tSchema at Installer.cls:2694 instead of hand-transcribing it. The spec must argue the fifth gate code: the fourth was avoided when both states meant keep waiting, and this one means waiting never helps
- 2026-09-13T21:01:57Z owner=1-18-epic-1-burn-down by=burndown note=chartered into the Epic 1 burn-down story, risk-led rather than sort-led: first-install and silent-refusal defects, release-blocking licence distribution, then CI reliability and vacuous pins
- 2026-09-13T23:43:36Z occurrence=1-18-epic-1-burn-down
- 2026-09-14T00:42:24Z status=resolved-by:1-18-epic-1-burn-down by=adjudication note=GateStatus answers unreadable instead of discarding a state-read failure as installing; install reads the grant back; schema name derived. Lead AD gate on a throwaway: REVOKE flipped readiness installed->unreadable and reinstall restored it. unreadable.browser-spec.mjs pins notice, focus and Retry against a non-%All user

### DW-97: An entity id containing two consecutive dots cannot deep-link: the AD-21 literal rejection refuses the whole path with 400, and the shared id corpus has no dotted row at all
- source: spec-1-5-the-static-shell-serves-the-spa-including-deep-links.md | severity: med | fix-risk: med | footprint: in-epic
- evidence: Kernel.EntityId.PercentEncode leaves '.' untouched, so Encode('a..b') is 'a..b'; StaticHandler.ResolvePath refuses any relative path containing '..' and answers 400 STATIC.BADPATH instead of index.html. Confirmed live: GET /ocupilot/permissions/users/a..b returns 400 application/json. Test.EntityId.Corpus and ui/tools/entity-id.test.mjs contain no '.' in any row.
- 2026-09-12T01:28:33Z status=routed owner=1-9-the-screen-descriptor-registry-and-privilege-driven-navigati by=cr note=spec-bound today (the I/O matrix specifies 400 for any path containing ..); 1.9 is the first story to put ids in routes and owns the choice: dot-segment check plus an AD-21 amendment, or a codec that never emits a literal ..
- 2026-09-12T13:45:10Z status=resolved-by:1-9-the-screen-descriptor-registry-and-privilege-driven-navigati by=adjudication note=fixed in the codec by escaping . to %2E on both sides, not by amending AD-21's traversal rejection; both corpora gained the dotted row so a one-sided change goes red

### DW-98: StaticHandler.ContentTypeFor's closed table omits wasm, avif, otf and xml, which X-Content-Type-Options nosniff turns from untyped into unusable
- source: spec-1-5-the-static-shell-serves-the-spa-including-deep-links.md | severity: low | fix-risk: low | footprint: in-story
- evidence: ContentTypeFor falls back to application/octet-stream; with nosniff a browser refuses the asset outright rather than guessing, and WebAssembly.instantiateStreaming rejects the fallback. Today's bundle emits only html, js, css and woff2, so none is reachable.
- 2026-09-12T01:28:33Z status=wontfix-accepted owner=burndown by=cr note=reopen_if=the Angular build emits an asset whose extension ContentTypeFor lacks (check build-output.test.mjs's emitted-file list)

### DW-99: The start hook's helper children (grep, head, sed, tail, cut inside print_tail and start_key) inherit stderr uncaptured, which /iris-main reads as a failed start
- source: spec-1-5-the-static-shell-serves-the-spa-including-deep-links.md | severity: low | fix-risk: med | footprint: out-of-footprint
- evidence: ui/tools/compose.test.mjs enforces two things only: no >&2 in the hook's own lines, and 2>&1 on both iris session calls. The helper functions' children are neither wrapped nor tested. All of them read from pipes and variables rather than files, so none has an input it can fail on; the header claim was narrowed at review to say exactly this.
- 2026-09-12T01:28:47Z status=wontfix-theoretical owner=burndown by=cr note=becomes real if a helper is ever given a file argument, or if a child is added that can fail on its input; the fix is to wrap each function body in { ... } 2>&1 and verify on a throwaway container

### DW-100: The client and server entity-id corpora are described as one shared table but pin different row sets (8 rows against 5), so three rows cannot fail together
- source: spec-1-5-the-static-shell-serves-the-spa-including-deep-links.md | severity: low | fix-risk: med | footprint: in-story
- evidence: ui/tools/entity-id.test.mjs pins expected encodings for 8 rows; Test.EntityId.TestBrowserEncodedInputMatchesTheServerCodec pins 5, omitting x?y, #frag and /csp/myapp. The main corpus tests do share Test.EntityId.Corpus, so the wire contract itself is covered; only the browser-encoded comparison table diverges.
- 2026-09-12T01:28:47Z status=wontfix-accepted owner=burndown by=cr note=reopen_if=a row present in one table and absent from the other is what a regression turns up; aligning them means recomputing browser-encoded expectations for three rows, which is more than a fix-pack item

### DW-101: The INSTALL.* classifier isInstallInFlight has no production call site: ApiService never reads an envelope code, so a 503 during install reaches the caller raw
- source: spec-1-6-silent-first-sign-in.md | severity: med | fix-risk: low | footprint: in-epic
- evidence: ui/src/app/core/api.ts request() returns without inspecting the envelope; session.isInstallInFlight is only called from the probe path. Story 1.8 adds the first data call, which is where a 503-during-install is actually observable.
- 2026-09-12T05:04:58Z status=routed owner=1-8-instance-identity-and-the-api-version-guard by=harvest note=DW-1's positive half; 1.6 shipped the classifier and the negative test, 1.8 wires it to the first data call
- 2026-09-12T10:31:41Z status=resolved-by:1-8-instance-identity-and-the-api-version-guard by=adjudication note=ApiService.requestJson is the first production envelope reader and classifies INSTALL.* through the session classifier; pinned by the matrix row and its mutation

### DW-102: Two concurrent install-backoff probe chains are possible once a data call exists, each minting its own sid, the loser overwriting the winner's stored pair
- source: spec-1-6-silent-first-sign-in.md | severity: med | fix-risk: med | footprint: in-epic
- evidence: session.enterInstalling/probeAndSettle have no single-flight guard on the backoff chain (unlike the refresh path, which does). Unreachable in 1.6 because the probe is the only caller; 1.8's first data call makes a second chain reachable.
- 2026-09-12T05:04:58Z status=routed owner=1-8-instance-identity-and-the-api-version-guard by=harvest note=same shape as DW-4, which is fixed on the refresh path; reachable only with 1.8's data call
- 2026-09-12T05:43:27Z occurrence=1-6-silent-first-sign-in
- 2026-09-12T10:31:41Z status=resolved-by:1-8-instance-identity-and-the-api-version-guard by=adjudication note=fix was incomplete as first shipped - backoffArmed left the probe's own /login round trip unguarded - so the guard moved to a whole-chain installing-state check in noteInstallInFlight; mutation re-demonstrated by QA after the change

### DW-103: A rejected sign-in loses keyboard focus: formLogin enters probing, the card unmounts, and the re-rendered form leaves focus on the document body
- source: spec-1-6-silent-first-sign-in.md | severity: med | fix-risk: low | footprint: in-epic
- evidence: ui/src/app/shell/sign-in.ts re-renders through the probing state on rejection; nothing restores focus to the user-name field. A keyboard-only or screen-reader user must re-find the form after every failed attempt.
- 2026-09-12T05:04:58Z status=routed owner=1-10-header-status-bar-and-page-chrome by=harvest note=1.10 owns chrome and focus management across the shell
- 2026-09-12T07:17:39Z occurrence=1-7-sign-out
- 2026-09-12T07:52:59Z status=routed owner=1-10-header-status-bar-and-page-chrome by=cr note=1-7 differs: sign-out unmounts item and trigger together; the destination must be in sign-in.ts
- 2026-09-12T16:25:11Z status=resolved-by:1-10-header-status-bar-and-page-chrome by=adjudication note=closed by this story's tasks and pinned by the component runner; see the spec's Verification for the named mutation

### DW-104: A form submit that meets an unreachable instance is discarded with no message: formLogin's unavailable branch leaves refusalState at form, so the backoff probe's 401 shows a bare form
- source: spec-1-6-silent-first-sign-in.md | severity: med | fix-risk: low | footprint: in-epic
- evidence: formLogin's unavailable branch clears the password and enters installing; runRefresh's sibling branch sets refusalState=session-ended and formLogin's does not. No existing string fits a never-established session, and adding an EXPERIENCE.md row is the hazard this story is forbidden to trigger.
- 2026-09-12T05:43:27Z status=routed owner=1-13-uniform-error-handling-and-the-connectivity-probe by=cr note=1.13 owns the installing and connectivity copy per this spec's Design Notes; needs a string, not a state change
- 2026-09-12T23:59:51Z status=resolved-by:1-13-uniform-error-handling-and-the-connectivity-probe by=adjudication note=closed by the failure taxonomy and its recovery paths; the review found and fixed two siblings of the same shape - a parked recovery deleted by the notification meant to drive it, and a park whose only trigger was taken by the next verdict

### DW-105: The password-expired branch is unreachable AND its banner is unimplemented: it renders the literal <user> placeholder with no substitution and no links
- source: spec-1-6-silent-first-sign-in.md | severity: med | fix-risk: low | footprint: in-epic
- evidence: epics.md:1194 requires the variant to name the user and link to the classic portal and the README fix; sign-in.ts renders {{ STRINGS.authPasswordExpired }} verbatim and strings.ts:220 carries a literal <user>. The state has no trigger on this build (verified negative, this spec's Verification section).
- 2026-09-12T05:43:27Z status=routed owner=1-13-uniform-error-handling-and-the-connectivity-probe by=cr note=the discriminator half was already routed here in prose; this is the rendering half, unowned until now
- 2026-09-12T23:59:51Z status=resolved-by:1-13-uniform-error-handling-and-the-connectivity-probe by=adjudication note=closed by the failure taxonomy and its recovery paths; the review found and fixed two siblings of the same shape - a parked recovery deleted by the notification meant to drive it, and a park whose only trigger was taken by the next verdict

### DW-106: AD-28's Rule claimed 'Bearer alone leaves the browser-level login intact'; measured, that holds only for a superseded session
- source: spec-1-7-sign-out.md | severity: med | fix-risk: low | footprint: out-of-footprint
- evidence: Demonstrated by mutation on ocupilot-iris 2026-09-12: the cookie resolves to the most recently minted session in the group, so a Bearer-only logout of the current session ends the browser-level login too.
- 2026-09-12T07:17:39Z status=open owner=1-7-sign-out by=harvest note=spine claim, lead-owned per Rule 20
- 2026-09-12T07:17:39Z status=resolved-by:1-7-sign-out by=adjudication note=AD-28 amended at the source 2026-09-12 (memlog 57): sign-out always sends both and always means sign out of the instance; a tab-only sign-out is not offered

### DW-107: A refresh started AFTER sign-out finds no pair, falls through retryProbeThenEnd() to probeAndSettle(), and could re-mint from a browser-level login a failed logout left alive
- source: spec-1-7-sign-out.md | severity: med | fix-risk: med | footprint: in-epic
- evidence: signOutGeneration guards chains started BEFORE sign-out; runRefresh() returns retryProbeThenEnd() before its guard is consulted. Unreachable today because ApiService.request() has no production call site.
- 2026-09-12T07:17:39Z status=routed owner=1-8-instance-identity-and-the-api-version-guard by=harvest note=becomes reachable with 1.8's first data call, alongside DW-101/DW-102
- 2026-09-12T10:31:41Z status=resolved-by:1-8-instance-identity-and-the-api-version-guard by=adjudication note=a refresh started after sign-out can no longer re-mint; guarded and pinned, mutation re-verified at the review gate

### DW-108: Neither the signed-out banner (1.7) nor the session-ended banner (1.6) is announced to assistive technology, and EXPERIENCE.md's role=status enumeration is a closed list that excludes both
- source: spec-1-7-sign-out.md | severity: med | fix-risk: low | footprint: in-epic
- evidence: EXPERIENCE.md :582 enumerates the polite role=status messages and the role=alert ones; adding either banner deviates from a closed UX enumeration, so it is an owner call, not a patch.
- 2026-09-12T07:17:39Z status=decision-pending owner=burndown by=harvest note=UX amendment for the decision sheet; covers both banners so their treatment cannot split
- 2026-09-12T09:46:32Z occurrence=1-8-instance-identity-and-the-api-version-guard
- 2026-09-12T09:46:32Z status=decision-pending owner=burndown by=harvest note=third surface: the blocking instance notice replaces the whole product surface with no heading, no live region and no focus move. Same blocker as the banners - EXPERIENCE.md's announcement enumeration is closed - so the owner's call covers all three
- 2026-09-13T14:46:51Z status=by-design by=decision-sheet note=announcement enumeration opened. EXPERIENCE.md :585 now lists the signed-out and session-ended banners as polite role=status and the blocking notice as role=alert with a heading and a focus move; sign-in.ts and instance-notice.ts changed to match. Whether an inserted live region announces is a real-browser question, routed with DW-159

### DW-109: The account menu stays open when the user clicks or tabs outside it, with aria-expanded=true and Escape no longer reachable
- source: spec-1-7-sign-out.md | severity: med | fix-risk: med | footprint: in-epic
- evidence: It closes only on Escape (bound on the wrapper div), a second trigger click, and choosing the item. EXPERIENCE.md :532 names only Escape, so this is inside the letter of the intent.
- 2026-09-12T07:17:39Z status=routed owner=1-10-header-status-bar-and-page-chrome by=harvest note=1.10 moves this component into the real status bar and owns chrome dismissal behaviour
- 2026-09-12T16:25:11Z status=resolved-by:1-10-header-status-bar-and-page-chrome by=adjudication note=closed by this story's tasks and pinned by the component runner; see the spec's Verification for the named mutation

### DW-110: ui/tools/strings.test.mjs locates EXPERIENCE.md's Fixed strings table by the hardcoded line range 252..302, so any insertion above line 252 silently shifts what it reads
- source: spec-1-7-sign-out.md | severity: med | fix-risk: low | footprint: in-story
- evidence: strings.test.mjs:47. The range is now cited in two specs and one source file as a reason not to add a table row - a test limitation quoted as a product constraint. Locating the table by its heading removes it.
- 2026-09-12T07:17:39Z status=open owner=1-7-sign-out by=harvest note=two-way door; the reviewer may patch it in-pass
- 2026-09-12T07:52:59Z status=resolved-by:1-7-sign-out by=cr note=located by the **Fixed strings** heading and its header row; demonstrated red/green on a 1-line insert

### DW-111: id=ocu-account-trigger is a document-global constant, so a second instance of the account menu breaks the panel's aria-labelledby
- source: spec-1-7-sign-out.md | severity: low | fix-risk: low | footprint: in-epic
- evidence: Harmless today - app.ts mounts exactly one - and it bites the moment Story 1.10 mounts the component into the status-bar band while the interim mount still exists. A per-instance id generated in the component settles it.
- 2026-09-12T07:17:58Z status=wontfix-accepted owner=1-7-sign-out by=harvest note=reopen_if=a second account-menu instance is mounted anywhere in the app (Story 1.10's status-bar move is the expected trigger)

### DW-112: src/OcuPilot/Test/Token.cls is 686 lines, past the roughly-500-line guidance for a %UnitTest class
- source: spec-1-7-sign-out.md | severity: low | fix-risk: low | footprint: in-story
- evidence: .claude/rules/objectscript-testing.md: keep a test class to roughly 500 lines. The four logout methods plus PostTokenTo/LogoutAt/BrowserCookie would move cleanly into a sibling class.
- 2026-09-12T07:17:58Z status=wontfix-accepted owner=1-7-sign-out by=harvest note=reopen_if=Token.cls passes 800 lines or a single-class run becomes too slow to re-run per gate

### DW-113: The spec's two manual browser checks were not performed at implement: the keyboard path and the post-sign-out reload were never observed in a real browser
- source: spec-1-7-sign-out.md | severity: med | fix-risk: low | footprint: in-story
- evidence: Both need the bundle in the live container, and the sign-out check ends a browser-level %ISCMgtPortal login - which the implement stage correctly refused to do while the owner holds a live session. The lead's smoke gate can do it in an isolated browser context whose session it minted itself.
- 2026-09-12T07:17:58Z status=open owner=1-7-sign-out by=harvest note=for the lead's smoke gate; isolated context, own portal login, never the owner's session
- 2026-09-12T07:55:59Z status=resolved-by:1-7-sign-out by=adjudication note=both manual checks performed at the lead smoke gate in an isolated browser context with its own portal login: menu opens with focus on Sign out, sign-out clears the pair and shows the banner with no name pre-filled, and a reload lands on the form rather than silently re-minting

### DW-114: Session.signOut()'s logout POST sets no keepalive, so a document unload before the request bytes leave the client loses the logout
- source: spec-1-7-sign-out.md | severity: med | fix-risk: low | footprint: in-story
- evidence: ui/src/app/core/session.ts:445. The request is dispatched synchronously inside chooseSignOut() on a warm connection, before any human action, so the window is narrow; adding keepalive changes the one request the story rests on with no browser-executed test to falsify it.
- 2026-09-12T07:53:13Z status=wontfix-accepted owner=1-7-sign-out by=cr note=reopen_if=a logout the tab reported sent leaves the browser-level login alive after a tab close

### DW-115: The account menu ships role=menu/role=menuitem without the arrow, Home/End or roving tabindex model those roles imply
- source: spec-1-7-sign-out.md | severity: low | fix-risk: low | footprint: in-epic
- evidence: ui/src/app/shell/account-menu.ts:65. With one item there is nowhere to arrow to and the item already holds focus on open; EXPERIENCE.md's Interaction Primitives defines an arrow model for the side-bar and table rows but none for menus, so there is no UX contract to build against. Distinct from DW-109 (dismissal).
- 2026-09-12T07:53:13Z status=wontfix-accepted owner=1-7-sign-out by=cr note=reopen_if=the account menu carries a second role=menuitem

### DW-116: Token.cls discards the %Status from its PostToken/PostTokenTo/GetApiRoot call sites, so a transport failure reads as 'expected 200, got 0'
- source: spec-1-7-sign-out.md | severity: low | fix-risk: low | footprint: in-story
- evidence: .claude/rules/objectscript-basics.md requires every %Status caller to check $$$ISERR. Diagnostics only, on an already-red run; this story's three new wire tests take the file from roughly 15 such call sites to 27, past a fix-pack item.
- 2026-09-12T07:53:13Z status=wontfix-accepted owner=1-7-sign-out by=cr note=reopen_if=a Token.cls failure reports 'expected 200, got 0' and the transport error is needed to diagnose it

### DW-117: AD-28's 'most recently minted session' mechanism and its 'any sibling JWT application' scope are asserted flatly from a two-application probe, with no (inference) label
- source: spec-1-7-sign-out.md | severity: low | fix-risk: low | footprint: out-of-footprint
- evidence: ARCHITECTURE-SPINE.md:352 plus five restatements (memlog, session.ts, Token.cls, this spec twice). The conclusion is mechanism-backed - the credentialled logout deletes the group node ^%cspSession(-3,'%iscmgtportal:<browserId>') - so only the labelling is short. Spine writes are the lead's under Rule 20.
- 2026-09-12T07:53:13Z status=wontfix-accepted owner=1-7-sign-out by=cr note=reopen_if=any JWT app in the %ISCMgtPortal group still mints after a credentialled logout
- 2026-09-12T07:57:13Z status=resolved-by:1-7-sign-out by=lead note=fixed at the origin rather than accepted: AD-28 now states the observed mechanism (the group session node is deleted, two of nine JWT apps measured) and labels the population claim (inference). memlog 58

### DW-118: The --ocu-* colour layer is theme-static: :root.ocu-theme-dark remaps only --mat-sys-*, so every colour in _components.scss keeps its light value in dark mode
- source: spec-1-8-instance-identity-and-the-api-version-guard.md | severity: med | fix-risk: med | footprint: out-of-footprint
- evidence: Pre-existing from Story 1.2's design system and whole-file; newly visible because this story is the first to use those colours on a full-surface component.
- 2026-09-12T09:46:45Z status=routed owner=15-6-the-light-and-dark-theme by=harvest note=Story 15.6 owns the light and dark theme and is where the remap belongs
- 2026-09-12T16:21:41Z occurrence=1-10-header-status-bar-and-page-chrome
- 2026-09-12T16:21:41Z status=routed owner=15-6-the-light-and-dark-theme by=cr note=1.10s :root.ocu-theme-dark .ocu-server-flag reads --ocu-on-shell-dark, the one component rule naming a -dark token; the pairing it computes never occurs
- 2026-09-12T23:55:35Z occurrence=1-13-uniform-error-handling-and-the-connectivity-probe

### DW-119: An identity call that fails in a way that is neither AUTH.NOADMIN nor INSTALL.* leaves the shell on 'checking' with nothing scheduled to ask again, so a signed-in tab can sit on a blank content area
- source: spec-1-8-instance-identity-and-the-api-version-guard.md | severity: med | fix-risk: med | footprint: in-story
- evidence: No retry is scheduled for an unclassified failure; the tab waits until something else moves the session.
- 2026-09-12T09:46:45Z status=open owner=1-8-instance-identity-and-the-api-version-guard by=harvest note=real user-visible dead end; the reviewer may patch it in-pass
- 2026-09-12T10:31:41Z status=routed owner=1-13-uniform-error-handling-and-the-connectivity-probe by=adjudication note=HALF closed: QA pinned that a generic failure settles nothing, so a later verify can still answer. NOT closed: nothing schedules that later verify. 1.13 owns uniform error handling and the connectivity probe, which is where a retry belongs
- 2026-09-12T23:59:51Z status=resolved-by:1-13-uniform-error-handling-and-the-connectivity-probe by=adjudication note=closed by the failure taxonomy and its recovery paths; the review found and fixed two siblings of the same shape - a parked recovery deleted by the notification meant to drive it, and a park whose only trigger was taken by the next verdict

### DW-120: Api.Instance.Handle()'s internal-error branch is reachable in production and exercised by no test, so the first route's failure path could stop producing OcuPilot's one envelope unnoticed
- source: spec-1-8-instance-identity-and-the-api-version-guard.md | severity: med | fix-risk: low | footprint: in-story
- evidence: Nothing makes Payload return an error, so the branch never executes under test.
- 2026-09-12T09:46:45Z status=open owner=1-8-instance-identity-and-the-api-version-guard by=harvest note=falsifiability gap on the first route's failure path
- 2026-09-12T10:31:41Z status=resolved-by:1-8-instance-identity-and-the-api-version-guard by=adjudication note=QA added InstanceFixture.SetVerificationThrows plus an /instance-fault fixture route; TestHandleRendersTheInternalErrorEnvelopeWhenVerificationThrows drives the branch through a real Throw. Reviewer confirmed it is executed, not a stub

### DW-121: The admin API version OcuPilot requires is stated in two languages - AdminPort's APIVERSION and the client's REQUIRED_ADMIN_API_VERSION - with no check that they agree
- source: spec-1-8-instance-identity-and-the-api-version-guard.md | severity: med | fix-risk: low | footprint: in-story
- evidence: Each half is pinned to its own surface; nothing fails if they drift apart.
- 2026-09-12T09:46:45Z status=open owner=1-8-instance-identity-and-the-api-version-guard by=harvest note=a single test reading both closes it
- 2026-09-12T10:31:41Z status=resolved-by:1-8-instance-identity-and-the-api-version-guard by=adjudication note=QA added a cross-language test reading AdminPort.cls's Parameter APIVERSION and comparing it to the client's REQUIRED_ADMIN_API_VERSION; drift now fails the client suite

### DW-122: ProbeAnswers' third branch - an endpoint answering ShouldRunAsync() with a non-boolean rather than throwing - has no fixture mode and no test
- source: spec-1-8-instance-identity-and-the-api-version-guard.md | severity: low | fix-risk: low | footprint: in-story
- evidence: ProbeFixture offers ok / noconstruct / noresources / asyncthrows; the non-boolean mode is absent.
- 2026-09-12T09:46:45Z status=open owner=1-8-instance-identity-and-the-api-version-guard by=harvest note=small fixture addition; two-way door
- 2026-09-12T10:31:41Z status=resolved-by:1-8-instance-identity-and-the-api-version-guard by=adjudication note=QA added ProbeFixture's asyncnonboolean mode and a Test.Instance method reaching the previously undriven branch

### DW-123: EXPERIENCE.md's Fixed strings table has no row for the version-mismatch sentence, which the same document authors inline in the States table, so strings.test.mjs carried it as a named exception
- source: spec-1-8-instance-identity-and-the-api-version-guard.md | severity: low | fix-risk: low | footprint: out-of-footprint
- evidence: The Fixed strings table at :248 is declared canonical over every inline quotation; the sentence lived only at :427 and in REQUIRED_ALONGSIDE_TABLE.
- 2026-09-12T09:47:33Z status=open owner=1-8-instance-identity-and-the-api-version-guard by=harvest note=planning-artifact amendment, reserved to the lead under Rule 5
- 2026-09-12T09:47:33Z status=resolved-by:1-8-instance-identity-and-the-api-version-guard by=lead note=row added to the Fixed strings table and the named exception removed from strings.test.mjs; suite 238/238. The string now comes from the canonical source rather than a test-side allowance

### DW-124: AdminPort derives the admin API version from the class-DEFINITION UrlMap XData, so an IRIS build shipping %Api.Admin with its source removed reports version 0 and blocks the whole product on a healthy instance
- source: spec-1-8-instance-identity-and-the-api-version-guard.md | severity: med | fix-risk: med | footprint: in-story
- evidence: Probed 2026-09-12 on ocupilot-iris: 133 %-classes already ship Deployed=1 (source removed); %Api.Admin is not one today and carries both a definition and a compiled UrlMap XData. Reading %Dictionary.CompiledXData instead survives source removal but breaks the parity AdminPort's own doc claims: the vendor's Info() reads the same definition dictionary and would report its seed of 1. Test.Instance.TestTheRealAdminApiIsReportedAtVersionTwo goes red at such an upgrade, which is AD-27's designed catch.
- 2026-09-12T10:27:48Z status=escalated owner=burndown by=cr note=parity with vendor Info() vs robustness to deployed source; suite catches it at upgrade (AD-27), so not blocking
- 2026-09-13T14:46:52Z status=wontfix-theoretical by=decision-sheet note=leave AdminPort reading the class definition. %Api.Admin ships with source today, the failure is hypothetical, and Test.Instance's version assertion is AD-27's designed catch at exactly that upgrade. Reading compiled XData would trade a real documented parity property for a hypothetical one
- 2026-09-13T14:51:20Z by=lead note=lead AD gate 2026-09-13 verified live: %Api.Admin and both Dispatch.v1/v2 carry Deployed=0, VerifyInstance returns OK with version 2, and HighestDispatchVersion reads 2 for %Api.Admin against 0 for another class, so the value is read and not constant. Sharpening the evidence rather than reopening: five classes in this same %Api.Admin package DO ship Deployed=2, so vendor source removal here is established practice, not a thought experiment. The decision stands because the dispatch classes are what AdminPort reads and AD-27's suite catches the day that changes

### DW-125: AD-44 stated the classic portal keys custom page resources by normalized page URL; the live API keys them by normalized class name
- source: spec-1-9-the-screen-descriptor-registry-and-privilege-driven-navigati.md | severity: med | fix-risk: low | footprint: out-of-footprint
- evidence: %SYS.Portal.Resources' IdKey Page is a class name and NormalizePage turns a link into one (irissys/%SYS/Portal/Resources.cls:97-164); confirmed live, the store holds 0 rows.
- 2026-09-12T12:44:38Z status=open owner=1-9-the-screen-descriptor-registry-and-privilege-driven-navigati by=harvest note=spine claim, lead-owned under Rule 20
- 2026-09-12T12:44:38Z status=resolved-by:1-9-the-screen-descriptor-registry-and-privilege-driven-navigati by=lead note=AD-44 corrected at the source 2026-09-12 (memlog 60): a descriptor declares the class it replaces, never a URL

### DW-126: EXPERIENCE.md's Fixed strings table has no row for the eight area names, nor a permission-denied row, though the rail, tooltips, side-bar landmark, eyebrow and area tiles all render them
- source: spec-1-9-the-screen-descriptor-registry-and-privilege-driven-navigati.md | severity: med | fix-risk: low | footprint: out-of-footprint
- evidence: The story authorizes the names by extracting EXPERIENCE.md:64 rather than growing REQUIRED_ALONGSIDE_TABLE, whose own comment calls that the bypass it must not become. The table is declared canonical over every inline quotation.
- 2026-09-12T12:44:38Z status=escalated owner=burndown by=harvest note=planning-artifact amendment, owner's call at the decision sheet; same family as DW-123 which the lead closed for the version-mismatch sentence
- 2026-09-12T15:34:15Z occurrence=1-10-header-status-bar-and-page-chrome
- 2026-09-12T15:34:15Z status=escalated owner=burndown by=harvest note=three more surfaces this story renders have no Fixed-strings row: the status bar's Server/Instance/Licensed-to segment labels, the command bar's filter label, and the command box's two result-group labels. Same owner call, wider scope
- 2026-09-12T21:12:05Z occurrence=1-12-home
- 2026-09-12T21:43:08Z occurrence=1-13-uniform-error-handling-and-the-connectivity-probe
- 2026-09-12T21:43:08Z status=escalated owner=burndown by=spec_gate note=1.13 needs copy for five more failures: a deleted entity, a submit meeting an unreachable instance, a failed map read, the 403's action-to-take half, and Retry / Open messages.log in the action-names row. Still one owner call
- 2026-09-13T00:23:28Z occurrence=1-14-the-auto-refresh-framework
- 2026-09-13T00:23:28Z status=escalated owner=burndown by=spec_gate note=1.14 needs chip copy for refresh rates beyond off and 10s; statusAutoRefreshOn is a fixed literal with no <n> placeholder, so Release 1 permits only those two and the mirror throws on any other declared rate
- 2026-09-13T02:58:40Z occurrence=1-15-classic-portal-fallback-links
- 2026-09-13T02:58:40Z status=escalated owner=burndown by=spec_gate note=1.15's classic-link card ships without its caption: both UX documents describe it, neither publishes the literal, and strings.test.mjs's converse test makes inventing one a suite failure
- 2026-09-13T21:01:00Z status=routed owner=burndown by=merge_gate note=owner-delegated decision (sheet A3): the lead drafts the missing Fixed-strings rows and they go through the burn-down story's review - area names, permission-denied, status-bar labels, filter and result-group labels, the five 1.13 failure copies, refresh-rate chip copy, the classic-link card caption. Relaxing the converse test was rejected: it is the one mechanism keeping copy in one place
- 2026-09-13T21:01:57Z owner=1-18-epic-1-burn-down by=burndown note=chartered into the Epic 1 burn-down story, risk-led rather than sort-led: first-install and silent-refusal defects, release-blocking licence distribution, then CI reliability and vacuous pins
- 2026-09-14T00:42:24Z status=resolved-by:1-18-epic-1-burn-down by=adjudication note=EXPERIENCE.md Fixed strings rows added with matching strings.ts keys and render sites, under the converse test; keys whose screen does not exist yet name the story that renders them

### DW-127: DESIGN.md and EXPERIENCE.md disagree on whether the two blocking notices carry a banner
- source: spec-1-9-the-screen-descriptor-registry-and-privilege-driven-navigati.md | severity: low | fix-risk: low | footprint: out-of-footprint
- evidence: DESIGN.md:1066 against EXPERIENCE.md:348/:428/:429. It touches Story 1.8's shipped instance-notice, not only this story's gated appearance.
- 2026-09-12T12:44:38Z status=escalated owner=burndown by=harvest note=document conflict for the owner; resolving it may change a shipped component
- 2026-09-13T14:46:51Z status=by-design by=decision-sheet note=resolved by the new precedence rule. DESIGN.md :1066 owns treatment, so no banner is stacked above the empty state; EXPERIENCE.md's three sites reworded to say the (error) is the colour treatment. instance-notice.ts already shipped this reading, so no code change

### DW-128: The navigation map is rebuilt from the class dictionary on every accessor call: each descriptor accessor reopens its XData and re-parses the JSON, and Roster calls ScreensForArea once per area
- source: spec-1-9-the-screen-descriptor-registry-and-privilege-driven-navigati.md | severity: med | fix-risk: med | footprint: in-story
- evidence: Measured 2.3 ms at one descriptor, scaling with descriptors x areas. Epic 2 adds descriptors in bulk.
- 2026-09-12T12:44:38Z status=open owner=1-9-the-screen-descriptor-registry-and-privilege-driven-navigati by=harvest note=reviewer may patch; otherwise adjudicate against a later story that adds descriptors in bulk
- 2026-09-12T13:45:10Z status=routed owner=2-3-one-descriptor-declared-read-serves-both-the-screen-and-its by=adjudication note=2.3 is the first story that adds descriptors in bulk, which is where the per-call rebuild (2.3 ms at one descriptor, scaling with descriptors x areas) starts to matter
- 2026-09-14T02:47:21Z owner=2-3-one-descriptor-declared-read-serves-both-the-screen-and-its by=x0 note=excluded: med fix-risk; the cache belongs with 2.3's descriptor accessor rework
- 2026-09-14T11:04:08Z status=resolved-by:2-3-one-descriptor-declared-read-serves-both-the-screen-and-its by=adjudication note=Descriptor.Base caches declarations per process keyed by the compiled class hash (0.13 us vs 66 us per read); Descriptor test pins call counts and invalidation after a recompile

### DW-129: The two readers of the same descriptor XData disagree on shape: check-objectscript.py silently skips a single-line XData block and screen-mirror.mjs mis-parses it
- source: spec-1-9-the-screen-descriptor-registry-and-privilege-driven-navigati.md | severity: med | fix-risk: med | footprint: in-story
- evidence: One source, two readers, and the readers do not agree on what they accept - a descriptor written in the skipped shape passes the checker and breaks the mirror.
- 2026-09-12T12:44:38Z status=open owner=1-9-the-screen-descriptor-registry-and-privilege-driven-navigati by=harvest note=reviewer may patch
- 2026-09-12T13:45:10Z status=resolved-by:1-9-the-screen-descriptor-registry-and-privilege-driven-navigati by=adjudication note=pinned on both sides (Python harness plus screen-mirror.test.mjs) and the Python half now runs in a gate - the review found it ran in none and wired it to the pre-commit hook

### DW-130: The DW-97 corpus closes the dot divergence but not the rest of its family: encodeURIComponent leaves ! ~ * ' ( ) unescaped where $ZConvert(...,'O','URL') does not
- source: spec-1-9-the-screen-descriptor-registry-and-privilege-driven-navigati.md | severity: med | fix-risk: med | footprint: in-story
- evidence: The paired corpora now carry a dotted row; the other six characters have no row on either side, so a one-sided change stays green.
- 2026-09-12T12:44:38Z status=open owner=1-9-the-screen-descriptor-registry-and-privilege-driven-navigati by=harvest note=same root shape as DW-97, one character class wider
- 2026-09-12T13:45:10Z status=resolved-by:1-9-the-screen-descriptor-registry-and-privilege-driven-navigati by=adjudication note=probed rather than assumed: only ~ actually diverges of the six named, and - had no row either; corpus rows added on both sides plus a dedicated tilde-divergence test

### DW-131: scripts/check-objectscript.py has no test harness, so the rescoped class-name cap and the new entity-type rule are pinned only by hand-applied mutations
- source: spec-1-9-the-screen-descriptor-registry-and-privilege-driven-navigati.md | severity: med | fix-risk: med | footprint: in-story
- evidence: The checker is the pinning gate for several ACs across the epic and nothing pins the checker.
- 2026-09-12T12:44:38Z status=open owner=1-9-the-screen-descriptor-registry-and-privilege-driven-navigati by=harvest note=QA may close this; it is the same shape as DW-35 routed to 1.17
- 2026-09-12T13:45:10Z status=resolved-by:1-9-the-screen-descriptor-registry-and-privilege-driven-navigati by=adjudication note=scripts/test_check_objectscript.py harness, 10/10, wired into .githooks/pre-commit by the review after it found the harness ran in no gate at all (Rule 8 HIGH)

### DW-132: The map-to-rail join is never exercised as one path: the wire contract is written once in ObjectScript and once in TypeScript with nothing deriving one from the other
- source: spec-1-9-the-screen-descriptor-registry-and-privilege-driven-navigati.md | severity: med | fix-risk: med | footprint: in-story
- evidence: All three components are tested against hand-written fixtures; no test takes the server's own payload into the client's renderer.
- 2026-09-12T12:44:38Z status=open owner=1-9-the-screen-descriptor-registry-and-privilege-driven-navigati by=harvest note=the component runner landing in this story makes this closeable
- 2026-09-12T13:45:10Z status=resolved-by:1-9-the-screen-descriptor-registry-and-privilege-driven-navigati by=adjudication note=rail-wire.spec.ts drives the real Rail component with the real /api/ocupilot/navigation body; the review replaced QA's hand-written LIVE_PAYLOAD, which was missing labelKey and Home's screens

### DW-133: Api.Navigation.Payload hand-copies each roster field rather than decorating the roster entry, so a field added to Registry.Roster is silently absent from the wire
- source: spec-1-9-the-screen-descriptor-registry-and-privilege-driven-navigati.md | severity: low | fix-risk: low | footprint: in-story
- evidence: Payload enumerates fields by name; Roster's ScreensForArea has the same shape.
- 2026-09-12T12:44:38Z status=open owner=1-9-the-screen-descriptor-registry-and-privilege-driven-navigati by=harvest note=two-way door if the reviewer can patch it
- 2026-09-12T13:45:10Z status=wontfix-accepted owner=1-9-the-screen-descriptor-registry-and-privilege-driven-navigati by=adjudication note=reopen_if=a field added to Registry.Roster or ScreensForArea is absent from the /api/ocupilot/navigation payload. Not worth a fix-pack now: Payload hand-copies four fields and the wire test would catch a rename, not an addition

### DW-134: Shell behaviour details left open: the Ctrl/Cmd+B chord does not exclude shiftKey, rail and side-bar navigation drop a ?ns= selection, and ShellState persists Home's collapse as a real state
- source: spec-1-9-the-screen-descriptor-registry-and-privilege-driven-navigati.md | severity: low | fix-risk: low | footprint: in-epic
- evidence: Each is small and independent; Story 1.10 owns the header, status bar and page chrome these live in.
- 2026-09-12T12:44:38Z status=routed owner=1-10-header-status-bar-and-page-chrome by=harvest note=1.10 owns shell chrome
- 2026-09-12T16:25:11Z status=resolved-by:1-10-header-status-bar-and-page-chrome by=adjudication note=closed by this story's tasks and pinned by the component runner; see the spec's Verification for the named mutation

### DW-135: A failed navigation-map read is indistinguishable from an un-asked one, and nothing retries: the shell stays ungated with no error surface
- source: spec-1-9-the-screen-descriptor-registry-and-privilege-driven-navigati.md | severity: med | fix-risk: med | footprint: in-epic
- evidence: navigation.ts runLoad() returns early on any non-ok result, loadedOnce stays false, and loaded() has no production reader - no component and not app.ts consults it. A 500 or a network failure on /navigation therefore leaves every areaVerdict/screenVerdict at UNGATED with nothing scheduled to ask again; only a 403 on some other call re-reads. The spec's Consumed-by already assigns 1.13 the retry this story's 403 re-read does not schedule.
- 2026-09-12T13:39:55Z status=routed owner=1-13-uniform-error-handling-and-the-connectivity-probe by=cr note=server stays the gate (AD-8) so this is presentation, not privilege; pairs with the failed-pair rendering 1.13 already owns
- 2026-09-12T23:59:51Z status=resolved-by:1-13-uniform-error-handling-and-the-connectivity-probe by=adjudication note=closed by the failure taxonomy and its recovery paths; the review found and fixed two siblings of the same shape - a parked recovery deleted by the notification meant to drive it, and a park whose only trigger was taken by the next verdict

### DW-136: AD-5's Rule still says the write-tool field lists are the only thing generated from a descriptor, while Story 1.9 ships a second generated artifact
- source: spec-1-9-the-screen-descriptor-registry-and-privilege-driven-navigati.md | severity: med | fix-risk: low | footprint: out-of-footprint
- evidence: ARCHITECTURE-SPINE.md AD-5: 'Only one thing is generated from it: the write tools field lists (AD-3)'. ui/tools/screen-mirror.mjs generates ui/src/app/core/screens.generated.ts from the same descriptors. epic-1-context.md authorizes it ('mirrored to the client as generated TypeScript') and AD-5 elsewhere permits resolution 'at build or startup', so the spine sentence is narrower than the epic context - a spine edit is the lead's (Rule 5, Rule 20), the same shape as this story's AD-44 correction.
- 2026-09-12T13:40:06Z status=escalated owner=burndown by=cr note=no implementation change wanted; the mirror serves AD-5's purpose - the sentence needs the lead's one-line sharpening
- 2026-09-13T14:46:52Z status=by-design by=decision-sheet note=AD-5's Rule sharpened under Rule 20: two things are generated from a descriptor, the write-tool field lists and the client screen mirror, both for the same reason. No implementation change

### DW-137: Two shell rows Story 1.9's tasks did not carry: Escape does not collapse the side bar, and the rail tooltip reveals with no 300 ms delay
- source: spec-1-9-the-screen-descriptor-registry-and-privilege-driven-navigati.md | severity: med | fix-risk: med | footprint: in-epic
- evidence: EXPERIENCE.md:533's keyboard model lists the side bar under Escape ('close the topmost overlay, else return focus to the screen'); side-bar.ts handles only the Ctrl/Cmd+B chord and the arrow keys. DESIGN.md:981 says the rail tooltip appears after 300ms; _components.scss reveals it immediately with no delay and no motion token. Both were read directly 2026-09-12.
- 2026-09-12T13:40:06Z status=routed owner=1-10-header-status-bar-and-page-chrome by=cr note=Escape needs the overlay stack 1.10 builds; the delay needs a motion token and allow-discrete, not a one-line CSS edit
- 2026-09-12T16:25:11Z status=resolved-by:1-10-header-status-bar-and-page-chrome by=adjudication note=closed by this story's tasks and pinned by the component runner; see the spec's Verification for the named mutation

### DW-138: Agent co-pilot is not pinned to the bottom of the rail: nothing in the tree gives the shell frame a height, so margin-top auto resolves to zero
- source: spec-1-9-the-screen-descriptor-registry-and-privilege-driven-navigati.md | severity: med | fix-risk: med | footprint: in-epic
- evidence: Read directly 2026-09-12: .ocu-rail-slot-bottom sets margin-top auto; .ocu-rail is a content-height flex column inside .ocu-shell, which is display flex with min-height 0 and no height, and no rule in ui/src/styles or ui/src/index.html gives html, body or app-root one (the only height anywhere is the sign-in scene's min-height 60vh). Agent therefore renders directly under Security, and the rail's background and the side bar's border stop at content height. No test in this suite observes rendered layout.
- 2026-09-12T13:42:32Z status=routed owner=1-10-header-status-bar-and-page-chrome by=cr note=the frame's height comes with the header and status bar 1.10 builds; picking a viewport value now cannot be verified without the browser check this story defers
- 2026-09-12T16:25:11Z status=resolved-by:1-10-header-status-bar-and-page-chrome by=adjudication note=closed by this story's tasks and pinned by the component runner; see the spec's Verification for the named mutation

### DW-139: DESIGN.md and EXPERIENCE.md diverge on chrome details with no precedence rule, so a builder cannot tell which document wins
- source: spec-1-10-header-status-bar-and-page-chrome.md | severity: med | fix-risk: low | footprint: out-of-footprint
- evidence: Four sightings in this story alone: the command-box placeholder width (DESIGN.md:1017 80% against epics.md:1351 and DESIGN.md:1007 no-text-below-100%), the lockup accessible name (DESIGN.md:287/:1011 'OcuPilot' against EXPERIENCE.md:316 'OcuPilot - Home'), a command-bar sort control EXPERIENCE.md:321 lists and DESIGN.md:1037 places in the table header instead, and a last-update stamp specified in both bars with no rule for which renders it. DW-127's banner disagreement is a fifth.
- 2026-09-12T15:34:15Z status=escalated owner=burndown by=harvest note=the owner's call at the decision sheet; a precedence rule would close all five at once
- 2026-09-12T21:43:08Z occurrence=1-13-uniform-error-handling-and-the-connectivity-probe
- 2026-09-12T21:43:08Z status=escalated owner=burndown by=spec_gate note=three more divergences: EXPERIENCE.md:397 scopes the banner to surfaces that exclude instance-unreachable while :436 and DESIGN.md:1201 put it there; full-width strip vs inline notice never floating; three connection words vs four
- 2026-09-13T00:23:28Z occurrence=1-14-the-auto-refresh-framework
- 2026-09-13T00:23:28Z status=escalated owner=burndown by=spec_gate note=DESIGN.md renders the last-update stamp in both the command bar and the status bar with no precedence rule; 1.14 put the stamp in the status bar and the chip in the command bar on EXPERIENCE.md:318's division of labour
- 2026-09-13T01:36:49Z occurrence=1-14-the-auto-refresh-framework
- 2026-09-13T14:46:51Z status=by-design by=decision-sheet note=owner granted full decision authority 2026-09-13. Precedence rule written into both UX documents: EXPERIENCE.md wins on behavior and copy, DESIGN.md on visual treatment, and where one contradicts itself the other resolves it. Six of the eight recorded divergences resolve mechanically

### DW-140: DW-138's rendered-geometry half is not falsifiable in jsdom, which computes no layout, so the rail's bottom pin is pinned structurally but not measured
- source: spec-1-10-header-status-bar-and-page-chrome.md | severity: med | fix-risk: low | footprint: in-story
- evidence: The component runner renders but does not lay out; the spec names a getBoundingClientRect() measurement for the lead's browser gate.
- 2026-09-12T15:34:15Z status=open owner=1-10-header-status-bar-and-page-chrome by=harvest note=closeable at the lead's smoke gate
- 2026-09-12T16:26:42Z status=resolved-by:1-10-header-status-bar-and-page-chrome by=adjudication note=measured at the lead's smoke gate with getBoundingClientRect on the live bundle: viewport 705, status bar top 681 height 24 so its bottom is exactly the fold, no vertical page scroll (the body margin fix holds), and the last rail item sits 8px from the rail's bottom - the pin is real

### DW-141: The command bar's filter field has neither an accessible name nor a non-empty description: matchCount is the empty string until a screen has rows, so aria-describedby points at nothing
- source: spec-1-10-header-status-bar-and-page-chrome.md | severity: med | fix-risk: low | footprint: in-story
- evidence: A screen-reader user reaches an unlabelled text field. EXPERIENCE.md publishes no filter label, which is why the name is missing (DW-126).
- 2026-09-12T15:34:15Z status=open owner=1-10-header-status-bar-and-page-chrome by=harvest note=reviewer may patch the description half without new copy
- 2026-09-12T16:21:42Z status=open owner=1-10-header-status-bar-and-page-chrome by=cr note=wider than the naming gap: nothing reads the filter signal and matchCount is a constant, so the field is inert on every screen
- 2026-09-12T16:25:18Z status=routed owner=1-12-home by=adjudication note=pinned this pass, not fixed: each needs either copy no planning artifact publishes (DW-126) or a UX call. 1.12 is the first story to render a real screen inside this chrome, where each becomes observable
- 2026-09-12T21:15:51Z status=routed owner=2-4-the-data-table by=adjudication note=HALF closed: the description half is fixed (no aria-describedby while matchCount is empty). NOT closed: the accessible name needs a Fixed-strings row, which is DW-126, the owner's. 2.4 is the first screen with rows, where the pairing becomes observable alongside DW-162
- 2026-09-14T02:47:20Z owner=2-4-the-data-table by=x0 note=excluded: pairs with DW-162, whose right-state assertion needs the rows 2.4 first provides
- 2026-09-14T13:49:49Z status=resolved-by:2-4-the-data-table by=adjudication note=the command bar filter is named Filter rows from EXPERIENCE.md Fixed strings and bound to the screen store; command-bar.spec.ts

### DW-142: With an entity selected the locator marks the screen segment aria-current=page and leaves it unlinked, so there is no route back from an entity view to its list
- source: spec-1-10-header-status-bar-and-page-chrome.md | severity: med | fix-risk: low | footprint: in-story
- evidence: The screen segment is the only affordance that would return the user to the list; marking it current removes it.
- 2026-09-12T15:34:15Z status=open owner=1-10-header-status-bar-and-page-chrome by=harvest note=
- 2026-09-12T16:25:11Z status=resolved-by:1-10-header-status-bar-and-page-chrome by=adjudication note=QA fixed it rather than pinning it: the screen segment becomes a link back to the list once an entity follows, and aria-current moves to the entity segment. The spec's deferred list and triage log still describe the old behaviour

### DW-143: The locator's area segment navigates into that area's first built screen without checking its privilege verdict, where the rail and the side bar both refuse
- source: spec-1-10-header-status-bar-and-page-chrome.md | severity: med | fix-risk: low | footprint: in-story
- evidence: Same fail-open family as the three this epic has already patched: one navigation affordance gates and another does not. The server still refuses, so this is a client affordance defect, not a privilege bypass.
- 2026-09-12T15:34:15Z status=open owner=1-10-header-status-bar-and-page-chrome by=harvest note=third affordance for the same gate; the rail and side bar already refuse
- 2026-09-12T16:25:18Z status=routed owner=1-12-home by=adjudication note=pinned this pass, not fixed: each needs either copy no planning artifact publishes (DW-126) or a UX call. 1.12 is the first story to render a real screen inside this chrome, where each becomes observable
- 2026-09-12T21:15:51Z status=resolved-by:1-12-home by=adjudication note=closed by this story and pinned; the review additionally found DW-145's own fix capped the content box with no box-sizing reset, so a long value ended in a cut word rather than an ellipsis - fixed with box-sizing border-box

### DW-144: Escape collapses the side bar through toggleOpen(), so a transient dismissal is written to the stored preference and every later area starts collapsed
- source: spec-1-10-header-status-bar-and-page-chrome.md | severity: low | fix-risk: low | footprint: in-story
- evidence: A dismissal and a preference are different intents sharing one writer.
- 2026-09-12T15:34:15Z status=open owner=1-10-header-status-bar-and-page-chrome by=harvest note=two-way door
- 2026-09-12T16:25:18Z status=routed owner=1-12-home by=adjudication note=pinned this pass, not fixed: each needs either copy no planning artifact publishes (DW-126) or a UX call. 1.12 is the first story to render a real screen inside this chrome, where each becomes observable
- 2026-09-12T21:15:51Z status=resolved-by:1-12-home by=adjudication note=closed by this story and pinned; the review additionally found DW-145's own fix capped the content box with no box-sizing reset, so a long value ended in a cut word rather than an ellipsis - fixed with box-sizing border-box

### DW-145: An unrecognised system mode is drawn verbatim, uncapped and nowrap, so a long value written directly to ^%SYS(SystemMode) would stretch the 24px status bar
- source: spec-1-10-header-status-bar-and-page-chrome.md | severity: low | fix-risk: low | footprint: in-story
- evidence: The setter normalises unknown values to empty, so this needs a direct global write - real but not reachable through the product.
- 2026-09-12T15:34:15Z status=open owner=1-10-header-status-bar-and-page-chrome by=harvest note=two-way door: a max-width and ellipsis
- 2026-09-12T16:25:18Z status=routed owner=1-12-home by=adjudication note=pinned this pass, not fixed: each needs either copy no planning artifact publishes (DW-126) or a UX call. 1.12 is the first story to render a real screen inside this chrome, where each becomes observable
- 2026-09-12T21:15:51Z status=resolved-by:1-12-home by=adjudication note=closed by this story and pinned; the review additionally found DW-145's own fix capped the content box with no box-sizing reset, so a long value ended in a cut word rather than an ellipsis - fixed with box-sizing border-box

### DW-146: The truncated instance-version segment is recoverable only through a title attribute, which is unreachable by keyboard and unreliable on touch
- source: spec-1-10-header-status-bar-and-page-chrome.md | severity: low | fix-risk: low | footprint: in-story
- evidence: The full version string is available nowhere else in the chrome.
- 2026-09-12T15:34:15Z status=open owner=1-10-header-status-bar-and-page-chrome by=harvest note=
- 2026-09-12T16:25:18Z status=routed owner=1-12-home by=adjudication note=pinned this pass, not fixed: each needs either copy no planning artifact publishes (DW-126) or a UX call. 1.12 is the first story to render a real screen inside this chrome, where each becomes observable
- 2026-09-12T21:15:51Z status=resolved-by:1-12-home by=adjudication note=closed by this story and pinned; the review additionally found DW-145's own fix capped the content box with no box-sizing reset, so a long value ended in a cut word rather than an ellipsis - fixed with box-sizing border-box

### DW-147: The command bar's view-options control is named by the AC and by DESIGN.md:1037 but is not rendered
- source: spec-1-10-header-status-bar-and-page-chrome.md | severity: low | fix-risk: low | footprint: in-story
- evidence: A doc comment called it out and no deferred entry existed until this pass.
- 2026-09-12T15:34:15Z status=open owner=1-10-header-status-bar-and-page-chrome by=harvest note=scope question for the reviewer: render it or decline it in the spec
- 2026-09-12T16:25:18Z status=routed owner=1-12-home by=adjudication note=pinned this pass, not fixed: each needs either copy no planning artifact publishes (DW-126) or a UX call. 1.12 is the first story to render a real screen inside this chrome, where each becomes observable
- 2026-09-12T19:44:46Z status=wontfix-accepted owner=1-12-home by=spec_gate note=declined with reason at the spec gate: EXPERIENCE.md publishes no label and no menu items for the view-options control, DESIGN.md and EXPERIENCE.md diverge on the adjacent sort control (DW-139), and Home has no view variants. reopen_if=a planning artifact publishes a label and the items for the view-options control, or a screen archetype ships view variants

### DW-148: Navigations that bypass ShellState.activateArea leave the side bar listing the previous area and never open it: the command box and the locator's area segment both call router.navigateByUrl alone
- source: spec-1-10-header-status-bar-and-page-chrome.md | severity: med | fix-risk: med | footprint: in-epic
- evidence: EXPERIENCE.md:320 says the locator's area segment opens the area's first screen AND its side-bar; locator-bar.ts open() and command-box.ts choose() only navigate. ScreenOutlet's setActiveArea (shell-state.ts:69-74, Story 1.9) never opens the bar and refuses to move visibleArea while it is open, so after a cross-area jump the rail marks the new area while the side bar still lists the old one. Closing it needs ShellState surface that does not exist (show an area's list without activateArea's click-to-collapse).
- 2026-09-12T16:21:05Z status=routed owner=burndown by=cr note=1.10 added the first two affordances that cross areas without activateArea; root cause is 1.9s setActiveArea guard
- 2026-09-12T21:12:05Z occurrence=1-12-home
- 2026-09-12T21:12:05Z status=routed owner=burndown by=cr note=1.12 added ShellState.showArea, the surface the evidence line says does not exist; locator open() can now call it
- 2026-09-13T21:00:47Z status=routed owner=2-5-the-web-applications-list by=burndown note=command box and locator area segment call router.navigateByUrl alone, bypassing ShellState.activateArea. 2-5 is the first real screen reachable through them
- 2026-09-14T02:47:21Z owner=2-5-the-web-applications-list by=x0 note=excluded: med fix-risk; needs new ShellState surface, first exercised by 2.5's cross-area navigation
- 2026-09-14T15:53:59Z occurrence=2-5-the-web-applications-list
- 2026-09-14T15:56:17Z status=routed owner=6-14-the-messages-log-viewer by=adjudication note=resolved for the command box (opens the bar only when already open) and the locator's area segment (web-applications.browser-spec AC6); residual: the fault banner's Open messages.log link navigates without ShellState.showArea and is unreachable until 6.14 builds the messages.log screen

### DW-149: No Skip to content link, and no ledger entry recorded the gap: the frame now puts banner, rail and side bar ahead of main in Tab order
- source: spec-1-10-header-status-bar-and-page-chrome.md | severity: med | fix-risk: low | footprint: in-epic
- evidence: EXPERIENCE.md:580 Accessibility Floor: 'A Skip to content link is the first Tab stop' (NFR-12, WCAG 2.4.1 Bypass Blocks, Level A). The spec's Boundaries decline it as needing 'a string neither document authorizes', but EXPERIENCE.md:580 publishes the literal on the same line, in the same form, as the 'Breadcrumb' this story did extract - strings.test.mjs's own comment in this diff says so. main already carries tabindex=-1, so only the link and its string are missing.
- 2026-09-12T16:21:17Z status=routed owner=burndown by=cr note=declined in the spec on a reason the loaded UX document contradicts; nothing carried the floor item to the drain until now
- 2026-09-12T21:12:05Z occurrence=1-12-home
- 2026-09-12T21:12:05Z status=routed owner=burndown by=cr note=Home is the first screen in the frame and carries no heading, so UX-DR68's route-change focus target does not exist
- 2026-09-13T21:00:47Z status=routed owner=2-5-the-web-applications-list by=burndown note=no Skip to content link while banner, rail and side bar precede main in Tab order. 2-5 is the first story with real content to skip to
- 2026-09-14T02:47:20Z owner=2-0-epic-1-deferred-cleanup by=x0 note=default-include: low fix-risk, lands before Epic 2 adds descriptors and actions in bulk
- 2026-09-14T04:31:22Z status=resolved-by:2-0-epic-1-deferred-cleanup by=adjudication note=Skip to content is the first Tab stop and focuses main without navigating; shell.browser-spec.mjs fresh load and in-app sign-in cases

### DW-150: OcuPilot.Api.Instance.LogSourceFailure's forward to Api.Error.LogError has no test host, so an emptied body would keep the suite green
- source: spec-1-10-header-status-bar-and-page-chrome.md | severity: low | fix-risk: med | footprint: in-story
- evidence: TestTheProductionLogSeamRunsAndSwallowsItsOwnFailure asserts only that the body does not throw; every other test reads Test.InstanceFixture's wholesale override. Api.Error.LogError is called by hard class name, so Test.LogProbe cannot intercept it (Test/Envelope.cls:107 records the same constraint) and Kernel.Audit.Log.Emit writes to the console log, not a readable global. The Matrix row's own pinning test is falsifiable one level up (deleting the LogSourceFailure call from LicensedTo's Catch goes red).
- 2026-09-12T16:21:17Z status=wontfix-accepted owner=burndown by=cr note=reopen_if=a refused status-bar read reaches production and messages.log carries no 'A status-bar source could not be read' line

### DW-151: The header lockup is a CSS background-image on an empty anchor, so it vanishes entirely under forced-colors
- source: spec-1-10-header-status-bar-and-page-chrome.md | severity: low | fix-risk: med | footprint: in-epic
- evidence: _components.scss .ocu-header-lockup draws the reversed PNG as background-image; header.spec.ts pins lockup.children at 0 and textContent at ''. Windows High Contrast (forced-colors: active) drops background images, leaving a 156x32 invisible link. Its aria-label survives, so assistive technology is unaffected; a sighted high-contrast user sees nothing where Home is. No forced-colors block exists anywhere in ui/src/styles.
- 2026-09-12T16:21:26Z status=wontfix-accepted owner=burndown by=cr note=reopen_if=a forced-colors pass finds the Home affordance unreachable by sight; a raster lockup needs an SVG or a visible-text fallback, not a 15-line patch

### DW-152: The status bar's connecting disc and statusConnectionSigningIn can never render in the composed app
- source: spec-1-10-header-status-bar-and-page-chrome.md | severity: low | fix-risk: low | footprint: in-epic
- evidence: StatusBar.connectionState/connectionWord branch on isSignedIn(session.state()), and app.ts mounts app-status-bar only inside @if (signedIn) nested in @if (instanceReady) - so inside that branch the predicate is always true. status-bar.spec.ts exercises the arm only because the component is mounted in isolation. Story 1.13's connectivity probe is what supplies states the session cannot.
- 2026-09-12T16:21:26Z status=wontfix-accepted owner=burndown by=cr note=reopen_if=1.13 lands the probe and the segment still reads Connected while the probe says unreachable

### DW-153: A screen's primary action is drawn as a fully enabled button with no click handler, and the command box offers the same row as selectable and then silently closes
- source: spec-1-10-header-status-bar-and-page-chrome.md | severity: med | fix-risk: low | footprint: out-of-footprint
- evidence: command-bar.ts renders the primary action with no (click), no aria-disabled and no reason; command-box.ts choose() falls through to close() for a non-row-scoped action row. Row actions were deliberately given aria-disabled plus 'Select a row first' because 'a row the box offered as selectable and then silently ignored would say the opposite of what the bar says' - the primary action is exactly that, unguarded. Not reachable in Epic 1: the only shipped descriptor, Home, declares primaryAction.id = '' and rowActions [] (screens.generated.ts:224-228), so neither control renders today.
- 2026-09-12T16:21:36Z status=routed owner=burndown by=cr note=becomes user-reachable with the first descriptor that declares a primaryAction; Epic 2 owns running actions
- 2026-09-13T21:00:47Z status=routed owner=2-5-the-web-applications-list by=burndown note=a primary action draws enabled with no click handler and the command box offers it then closes. 2-5 carries the first real primary action (Create)
- 2026-09-14T02:47:20Z owner=2-0-epic-1-deferred-cleanup by=x0 note=default-include: low fix-risk, lands before Epic 2 adds descriptors and actions in bulk
- 2026-09-14T04:31:22Z status=resolved-by:2-0-epic-1-deferred-cleanup by=adjudication note=core/screen-actions.ts registry; command bar and command box offer a primary action only with a registered handler and run it once; command-bar.spec.ts and command-box.spec.ts

### DW-154: The command box's polite count region is inserted already populated, so the first result count is never announced
- source: spec-1-10-header-status-bar-and-page-chrome.md | severity: low | fix-risk: med | footprint: in-story
- evidence: command-box.ts's <p class=ocu-command-box-count role=status> lives inside @if (expanded), so the live region and its first text enter the DOM together; screen readers generally do not announce a region inserted already populated. Only subsequent filter changes announce. EXPERIENCE.md:580 lists the command-box count among its polite role=status regions. Moving the element outside the sheet is three lines but relocates it into the header band, whose rendered geometry this story has never observed in a browser.
- 2026-09-12T16:21:36Z status=wontfix-accepted owner=burndown by=cr note=reopen_if=a screen-reader pass over the opened box hears no count until the filter is edited

### DW-155: The namespace switch's trigger has no accessible name saying what it controls: its name is the namespace value alone, and the word Namespace is a sibling span with no aria-labelledby
- source: spec-1-11-the-namespace-switch-as-data-scope.md | severity: med | fix-risk: low | footprint: in-story
- evidence: A screen-reader user hears the value with no indication of what it selects. The word exists in header.ts already, so this is a wiring fix, not new copy.
- 2026-09-12T18:24:10Z status=open owner=1-11-the-namespace-switch-as-data-scope by=harvest note=reviewer or QA may patch; needs no new string
- 2026-09-12T19:12:50Z status=resolved-by:1-11-the-namespace-switch-as-data-scope by=cr note=verified: header.ts id + trigger aria-labelledby + value id; pinned in header.spec.ts with a demonstrated mutation
- 2026-09-12T19:18:18Z status=resolved-by:1-11-the-namespace-switch-as-data-scope by=adjudication note=header eyebrow given an id and wired to the trigger with aria-labelledby, no new copy; the review confirmed the pin has a demonstrated mutation

### DW-156: GET /namespaces calls %SYS.Namespace.GetAllNSInfo once per namespace with DontConnect defaulted to 0, so on an instance with ECP- or remote-mapped namespaces every list read attempts a connection
- source: spec-1-11-the-namespace-switch-as-data-scope.md | severity: med | fix-risk: med | footprint: in-story
- evidence: This container has no ECP or remote-mapped namespace, so the cost is invisible here and would appear on a customer instance that has one.
- 2026-09-12T18:24:10Z status=open owner=1-11-the-namespace-switch-as-data-scope by=harvest note=not reproducible on this instance; DontConnect=1 is the candidate fix
- 2026-09-12T19:12:56Z status=escalated owner=burndown by=cr note=needs an ECP- or remote-mapped namespace to reproduce or to test a fix; out of footprint for any Epic 1 story on this instance
- 2026-09-13T21:00:47Z status=routed owner=2-3-one-descriptor-declared-read-serves-both-the-screen-and-its by=merge_gate note=owner-delegated decision: set DontConnect=1 on GetAllNSInfo and accept it cannot be exercised on this instance (no ECP or remote-mapped namespace). 2-3 generalizes the read contract the namespaces list uses
- 2026-09-14T02:47:21Z owner=2-3-one-descriptor-declared-read-serves-both-the-screen-and-its by=x0 note=excluded: med fix-risk; 2.3 reworks the namespaces read
- 2026-09-14T11:04:08Z status=resolved-by:2-3-one-descriptor-declared-read-serves-both-the-screen-and-its by=adjudication note=Api.Namespaces calls GetAllNSInfo with DontConnect=1 through an overridable NamespaceInfo; NamespaceInfoFixture observes the flag

### DW-157: NavigationService.reload() joins a map read already in flight rather than queueing one, so a scope change inside that window leaves the map computed against the previous namespace
- source: spec-1-11-the-namespace-switch-as-data-scope.md | severity: med | fix-risk: med | footprint: in-story
- evidence: Same single-flight family as DW-4 and DW-102: joining an in-flight read is right for a duplicate request and wrong when the input changed.
- 2026-09-12T18:24:10Z status=open owner=1-11-the-namespace-switch-as-data-scope by=harvest note=third sighting of the join-vs-queue distinction in this epic
- 2026-09-12T19:12:56Z occurrence=1-11-the-namespace-switch-as-data-scope
- 2026-09-12T19:12:56Z status=routed owner=1-14-the-auto-refresh-framework by=cr note=cr upgrades fix-risk to high: app.ts starts both loads in one tick so the window is the cold sign-in path, and the naive queue fix loops via navigation.test.mjs:284; 1.14 owns re-fetch routing
- 2026-09-13T02:30:13Z status=resolved-by:1-14-the-auto-refresh-framework by=adjudication note=closed by generalization rather than a third local patch: ui/src/app/core/single-flight.ts joins on an unchanged key and marks dirty then re-runs once on a changed key, consumed by both the refresh tick and NavigationService.reload. The review traced the unbounded-loop hazard the routing reviewer recorded and confirmed the key is unchanged at navigation.test.mjs:285, so it joins and arms nothing

### DW-158: The declared screen scope is refused only by Screen.Registry.Validate, while the two build gates that refuse the sibling entity-type vocabulary do not read it
- source: spec-1-11-the-namespace-switch-as-data-scope.md | severity: med | fix-risk: low | footprint: in-story
- evidence: A bad scope fails at runtime where a bad entity type fails at the build gate - the same class of declaration with two different failure times.
- 2026-09-12T18:24:10Z status=open owner=1-11-the-namespace-switch-as-data-scope by=harvest note=check-objectscript.py and screen-mirror.mjs are the two gates
- 2026-09-12T19:12:50Z status=resolved-by:1-11-the-namespace-switch-as-data-scope by=cr note=both gates read Kernel.Scope; cr added the omitted-scope half to check-objectscript.py, which Registry.Validate also refuses
- 2026-09-12T19:18:18Z status=resolved-by:1-11-the-namespace-switch-as-data-scope by=adjudication note=build-time scope gate added to both check-objectscript.py and screen-mirror.mjs reading Kernel.Scope's own parameters; the review closed the half QA missed, a descriptor that omits scope entirely

### DW-159: No test exercises any UI surface against a real browser runtime: ui/ has no Playwright or browser-MCP harness, so every shell assertion since 1.5 is jsdom, which computes no layout
- source: spec-1-11-the-namespace-switch-as-data-scope.md | severity: high | fix-risk: high | footprint: out-of-footprint
- evidence: Rule 3 wants a browser-MCP or Playwright test asserting observable DOM/render state for a user-facing story, and says the lead's later manual smoke does not count. ui/package.json test is 'node --test tools/ && ng test' (vitest+jsdom); no browser dependency exists anywhere in ui/. The API half of Rule 3 IS satisfied by Test/Wire.cls over real HTTP.
- 2026-09-12T19:13:03Z status=routed owner=1-17-the-smoke-script-the-readiness-endpoint-and-ci by=cr note=epic-wide since 1.5, not introduced by 1.11; standing up a harness is CI infrastructure and the container still serves the pre-1.11 bundle
- 2026-09-12T21:12:05Z occurrence=1-12-home
- 2026-09-12T23:09:47Z occurrence=1-13-uniform-error-handling-and-the-connectivity-probe
- 2026-09-13T15:59:59Z status=resolved-by:1-17-the-smoke-script-the-readiness-endpoint-and-ci by=adjudication note=harness half delivered: ui/browser/shell.browser-spec.mjs on a pinned headless Chrome with npm run test:browser, 4/4 and red under a layout mutation. The back-fill of shell assertions since 1.5 is DW-222, which also carries DW-108 and DW-163

### DW-160: Home's panel-widening acceptance criterion cannot be surface-anchored in Epic 1: no panel component exists and none is built before Epic 4
- source: spec-1-12-home.md | severity: med | fix-risk: low | footprint: out-of-footprint
- evidence: AC4's own precondition - 'when the panel is present' - is false for all of Epic 1. Its tokens (--ocu-panel-home, --ocu-motion-panel-width-duration) already ship and are drift-tested, so nothing is lost by deferring the behaviour.
- 2026-09-12T20:38:09Z status=routed owner=4-3-the-docked-panel-present-on-every-route by=harvest note=the story that builds the docked panel also owns the remembered width it restores on leaving Home

### DW-161: A tile and the locator's area segment navigate into the area's first built screen without consulting that screen's own verdict, landing an allowed-area user on the refusal page where the side bar refuses in place
- source: spec-1-12-home.md | severity: med | fix-risk: med | footprint: in-epic
- evidence: Spec-bound: the I/O matrix specifies 'the first built route', so retargeting is an amendment, not a patch. DW-143 closed the area-level check; this is the screen-level one, and the pre-existing locator test that covered it was replaced by the DW-143 pin, so the behaviour is now unpinned too.
- 2026-09-12T20:38:09Z status=routed owner=1-13-uniform-error-handling-and-the-connectivity-probe by=harvest note=1.13 owns uniform error handling and is where a refusal landing becomes a designed surface
- 2026-09-12T23:55:35Z status=routed owner=1-13-uniform-error-handling-and-the-connectivity-probe by=cr note=residual 3rd site rail.ts:167 still takes screensForArea()[0]; latent, one navigating area
- 2026-09-12T23:59:51Z status=resolved-by:1-13-uniform-error-handling-and-the-connectivity-probe by=adjudication note=closed by the failure taxonomy and its recovery paths; the review found and fixed two siblings of the same shape - a parked recovery deleted by the notification meant to drive it, and a park whose only trigger was taken by the next verdict

### DW-162: The command bar's filter-to-count pairing is now asserted in no state: the branch that emits aria-describedby is unreachable while matchCount returns the empty string
- source: spec-1-12-home.md | severity: med | fix-risk: low | footprint: in-epic
- evidence: The DW-141 description fix removed the wrong-state assertion without a right-state one to replace it, because no screen has rows yet.
- 2026-09-12T20:38:09Z status=routed owner=2-4-the-data-table by=harvest note=2.4 is the first screen with rows, which is the first state where the pairing is observable
- 2026-09-14T02:47:20Z owner=2-4-the-data-table by=x0 note=excluded: needs rows, which 2.4 first provides
- 2026-09-14T13:49:49Z status=resolved-by:2-4-the-data-table by=adjudication note=the filter's aria-describedby names the <n> rows match count once a screen has rows; command-bar.spec.ts pins the right state over list-page rows

### DW-163: An unrecognised system mode is now ellipsized with no way to read it in full, and the clip reaches Home's instance line as well as the 24px status bar
- source: spec-1-12-home.md | severity: med | fix-risk: low | footprint: in-epic
- evidence: DW-145's fix traded an unbounded stretch for an unreadable value; the full text is now available nowhere. Same shape as DW-146, which this story closed by rendering the full version as page content.
- 2026-09-12T20:38:09Z status=escalated owner=burndown by=harvest note=needs a disclosure pattern no planning artifact publishes; owner's call alongside DW-126
- 2026-09-12T21:12:05Z status=escalated owner=burndown by=cr note=cr fixed the box-sizing so the ellipsis renders at all; the open half is only that the full value has no disclosure
- 2026-09-13T14:46:52Z status=by-design by=decision-sheet note=Home's instance line discloses the full mode, the 24px status bar keeps clipping - the same answer Story 1.12 gave the version at DW-146. ServerFlag gains an unbounded input; a title tooltip was refused because EXPERIENCE.md :554 bans hover-only affordances

### DW-164: DESIGN.md and EXPERIENCE.md give the tile caption as the area's screens so the contest task statement's parentheticals are visible on Home; rendering built screens only means all six captions are empty until Epic 2
- source: spec-1-12-home.md | severity: med | fix-risk: low | footprint: out-of-footprint
- evidence: AD-5 forbids a second source beside each descriptor's labelKey, so hard-coding the names is not available. The documents assume a fuller Home than Epic 1 builds.
- 2026-09-12T20:38:09Z status=escalated owner=burndown by=harvest note=owner's call: accept empty captions until Epic 2 fills them, or amend the documents
- 2026-09-13T14:46:52Z status=wontfix-accepted by=decision-sheet note=accept empty tile captions until Epic 2 fills them from descriptors. AD-5 forbids a second source and the documents assume a fuller Home than Epic 1 builds. Known cost: Home reads as unfinished to anyone demoing before Epic 2

### DW-165: A screen's declared archetype is never validated against ARCHETYPE_PAGES, so a mistyped archetype routes, builds and renders a blank content area with no message
- source: spec-1-12-home.md | severity: med | fix-risk: low | footprint: out-of-footprint
- evidence: archetype is a bare string on screens.generated.ts with no union or enum; screen-mirror.mjs copies it verbatim and screen-mirror --check compares it to itself. screen-outlet.ts's map comment declares 'an archetype with no entry renders nothing' as Epic 1's intended state, so no assertion today can tell that apart from a typo. From the second registered archetype on, a misspelling is a silently blank screen.
- 2026-09-12T21:12:11Z status=routed owner=2-4-the-data-table by=cr note=the first story to register a second archetype is the first that can assert every built screen's archetype resolves to a page
- 2026-09-14T02:47:20Z owner=2-0-epic-1-deferred-cleanup by=x0 note=default-include: low fix-risk, lands before Epic 2 adds descriptors and actions in bulk
- 2026-09-14T04:31:22Z status=resolved-by:2-0-epic-1-deferred-cleanup by=adjudication note=screen-mirror emits BuiltArchetypeKey and ARCHETYPE_PAGES requires every key; lead mutation removed home -> tsc TS2322; screen-outlet.spec.ts pins the key set

### DW-166: The expired-password banner links 'the README' to the repository's GitHub URL, putting the owner's account name in shipped copy and pointing at a repo that is private until the 2026-09-24 release
- source: spec-1-13-uniform-error-handling-and-the-connectivity-probe.md | severity: med | fix-risk: low | footprint: in-story
- evidence: sign-in.ts:37. The URL is the repo's real remote and is correct after release; UJ-5's judge arrives from it. Before release it 404s for anyone but the owner. The state is unreachable on this build (1.6 verified an expired password returns an ordinary 401), so the exposure is latent. It ships inside a private instance's bundle, so it is not publication.
- 2026-09-12T23:09:47Z status=decision-pending owner=burndown by=harvest note=owner's call at the decision sheet: keep the URL, unlink the phrase until release, or point at a release-neutral home
- 2026-09-13T14:46:52Z status=by-design by=decision-sheet note=the README phrase renders as words, not a link, until the repository is public on 2026-09-24. No account name in any shipped bundle; the sentence keeps its instruction. sign-in.ts, its spec and EXPERIENCE.md :427 all carry the restoration note

### DW-167: The connectivity probe has no timeout, so a connection that is accepted and never answered stalls the backoff chain indefinitely
- source: spec-1-13-uniform-error-handling-and-the-connectivity-probe.md | severity: med | fix-risk: med | footprint: in-story
- evidence: A half-open connection is accepted by the OS and never answered; fetch does not time out on its own, so the chain neither retries nor reports.
- 2026-09-12T23:09:47Z status=routed owner=1-17-the-smoke-script-the-readiness-endpoint-and-ci by=harvest note=1.17 owns readiness and CI, where a probe timeout is testable against a real endpoint
- 2026-09-13T15:59:59Z status=resolved-by:1-17-the-smoke-script-the-readiness-endpoint-and-ci by=adjudication note=closed in two halves. The probe's own read is bounded by an AbortSignal; code review found the other half - session.refresh() is single-flight and carried no signal, so a half-open /refresh stalled every caller - and bounded it in api.ts. Pinned by refresh-connectivity.wire.test.mjs

### DW-168: The banner's gated 'Open messages.log' control carries no reason, unlike every other gated control in the shell
- source: spec-1-13-uniform-error-handling-and-the-connectivity-probe.md | severity: low | fix-risk: low | footprint: in-epic
- evidence: Every other gated control names the missing pair through formatRequires; this one is gated silently.
- 2026-09-12T23:09:47Z status=wontfix-accepted owner=1-13-uniform-error-handling-and-the-connectivity-probe by=harvest note=reopen_if=a second gated control ships without its reason, or the owner's decision sheet settles DW-126's action-names row, which is where the wording would come from

### DW-169: The 'string' type hint on the rendered code cannot be falsified while IsValidCode refuses every numeric code
- source: spec-1-13-uniform-error-handling-and-the-connectivity-probe.md | severity: low | fix-risk: low | footprint: in-story
- evidence: The guard makes the assertion unreachable - a defensive pair where the outer guard subsumes the inner one.
- 2026-09-12T23:09:47Z status=wontfix-accepted owner=1-13-uniform-error-handling-and-the-connectivity-probe by=harvest note=reopen_if=IsValidCode is relaxed to admit a numeric code, at which point the hint becomes falsifiable and should be pinned

### DW-170: Api/Error.Render type-hints the code key as a string but not reason, so a digits-only reason would serialize as a JSON number
- source: spec-1-13-uniform-error-handling-and-the-connectivity-probe.md | severity: low | fix-risk: low | footprint: in-story
- evidence: Error.cls writes %Set("reason", pReason) with no type hint one line above %Set("code", pCode, "string"). No shipped caller passes a numeric reason: every Render* default is an English sentence and IsValidCode does not constrain pReason.
- 2026-09-12T23:55:44Z status=wontfix-theoretical owner=1-13-uniform-error-handling-and-the-connectivity-probe by=cr note=real the first time a caller passes a digits-only reason; add the same hint then

### DW-171: spec-1-13's frontmatter locations and Auto Run Result carry claims the same diff superseded, the failure mode CLAUDE.md names as claims mined later as evidence
- source: spec-1-13-uniform-error-handling-and-the-connectivity-probe.md | severity: low | fix-risk: low | footprint: in-story
- evidence: All five deferred[] location: lines miss their subject (sign-in.ts:34 vs :37, connectivity.ts:175 vs :206, fault-banner.ts:129, Error.cls:195 vs :220) and DW-166 disagrees; deferred[1] and the follow-up/residual paragraphs assert a crossing test QA added in this same diff; Auto Run Result says spec-1-12's row is unamended when 5eebe55 amended it; counts read 385/167 against 390/171.
- 2026-09-12T23:55:44Z status=wontfix-accepted owner=1-13-uniform-error-handling-and-the-connectivity-probe by=cr note=reopen_if a later spec or review cites one of these as evidence; the reviewer may not edit those sections
- 2026-09-12T23:59:51Z status=resolved-by:1-13-uniform-error-handling-and-the-connectivity-probe by=adjudication note=lead corrected the superseded claims at origin: the test counts (385/167 -> 390/171) and the paragraph saying spec-1-12's amendment was outstanding when 5eebe55 had already applied it

### DW-172: A tick that meets a fault kind the banner has no published copy for suspends auto-refresh for the rest of the session while the chip goes on reading its rate
- source: spec-1-14-the-auto-refresh-framework.md | severity: med | fix-risk: med | footprint: in-epic
- evidence: The suspend has no lift for a kind that arms no probe; the chip keeps showing a rate that will never fire, so the user is told refresh is on when it is off.
- 2026-09-13T01:36:49Z status=routed owner=2-4-the-data-table by=harvest note=2.4 is the first screen with rows, where a silently suspended refresh is observable
- 2026-09-13T02:25:46Z status=routed owner=2-4-the-data-table by=cr note=evidence overstated: ApiService reports onFault(null) on any success, so drain() lifts it. Not session-long
- 2026-09-14T02:47:20Z owner=2-4-the-data-table by=x0 note=excluded: med fix-risk; the banner copy and the refresh lift are 2.4 data-table behavior
- 2026-09-14T13:49:49Z status=resolved-by:2-4-the-data-table by=adjudication note=a refused tick keeps the rows, shows request refused with Retry, and resume() lifts only banner faults (AD-8); refresh.test.mjs and the real-ConnectivityService wire tests

### DW-173: The paused chip literal is a 55-character sentence in a nowrap flex item with no max-width, so it cannot fit a narrow command bar and reflows the row when it appears
- source: spec-1-14-the-auto-refresh-framework.md | severity: med | fix-risk: low | footprint: in-epic
- evidence: Same shape as DW-145: a bounded bar meeting an unbounded string. No published design covers the chip at narrow widths.
- 2026-09-13T01:36:49Z status=routed owner=1-15-classic-portal-fallback-links by=harvest note=next story in the epic that touches chrome layout; if it does not fit there, the burn-down gate takes it
- 2026-09-13T04:49:54Z status=resolved-by:1-15-classic-portal-fallback-links by=adjudication note=closed with the DW-145 recipe as spec-1-12 recorded it - six properties plus min-width:0 on the row, bound as max-width:100% against a shrinkable row so no number is invented. Pinned as stylesheet text; a width cannot be observed in jsdom

### DW-174: A ScreenDeclaration fixture is hand-built in eight spec files, so each new descriptor field is eight edits
- source: spec-1-14-the-auto-refresh-framework.md | severity: med | fix-risk: low | footprint: in-epic
- evidence: This story added two fields and paid the cost eight times; Epic 2 adds descriptors in bulk.
- 2026-09-13T01:36:49Z status=routed owner=2-3-one-descriptor-declared-read-serves-both-the-screen-and-its by=harvest note=2.3 adds the first descriptor-declared read and will feel this immediately; a shared fixture builder closes it
- 2026-09-14T02:47:20Z owner=2-0-epic-1-deferred-cleanup by=x0 note=default-include: low fix-risk, lands before Epic 2 adds descriptors and actions in bulk
- 2026-09-14T04:31:22Z status=resolved-by:2-0-epic-1-deferred-cleanup by=adjudication note=ui/src/app/testing/screen-declaration.ts replaces eleven hand-built fixtures; screen-fixture.test.mjs fails if one reappears or the builder drifts from the mirror

### DW-175: The spine's AD-43 counts ten auto-refreshing screens; EXPERIENCE.md :561 names six
- source: spec-1-14-the-auto-refresh-framework.md | severity: med | fix-risk: low | footprint: out-of-footprint
- evidence: Two planning artifacts state different counts of the same set. Nothing in Epic 1 depends on which is right - Story 2.3 onward does. Choosing a number needs the intended screen roster, which is the owner's to state, not the lead's to infer.
- 2026-09-13T01:36:49Z status=escalated owner=burndown by=harvest note=same family as DW-139 but involves the spine, not only DESIGN/EXPERIENCE; owner's call at the decision sheet
- 2026-09-13T14:46:52Z status=by-design by=decision-sheet note=six, not ten. AD-43 amended to carry EXPERIENCE.md :561's roster verbatim - Processes, Databases, Database details, Task schedule, Task details, System usage - because an enumeration naming every member beats a bare count

### DW-176: The 'no area screen carries a timer of its own' scan ranges over one screen, so it pins nothing this change could have broken
- source: spec-1-14-the-auto-refresh-framework.md | severity: low | fix-risk: low | footprint: in-story
- evidence: Home is the only built screen, so the scan's population is one and its assertion is vacuous until Epic 2.
- 2026-09-13T01:36:49Z status=wontfix-accepted owner=1-14-the-auto-refresh-framework by=harvest note=reopen_if=a second area screen ships, at which point the scan has a real population and should be re-read

### DW-177: AD-19 says screen state is a signal store whose components read signals; screen-store.ts is a plain subscribable that components mirror into signals
- source: spec-1-14-the-auto-refresh-framework.md | severity: med | fix-risk: high | footprint: out-of-footprint
- evidence: AD-19's Rule: 'live in a signal store ... components read signals'. screen-store.ts holds Set<() => void> + subscribe()/notify() and imports no @angular/core; status-bar.ts:128 and command-bar.ts:216 mirror it into a signal(0) generation counter. The deviation is instance.ts's, not this story's, but this is the first store AD-19 literally describes and the precedent binds all 60 screens. core/ must stay framework-free for node --test.
- 2026-09-13T02:25:57Z status=decision-pending owner=burndown by=cr note=Rule 20: either amend AD-19's Rule to name the framework-free store + signal mirror, or change the shape. Owner's call at the decision sheet
- 2026-09-13T14:46:52Z status=by-design by=decision-sheet note=AD-19 amended to name the framework-free store plus signal mirror as the shape. core/ stays free of @angular/core so it runs under node --test, which is the suite that pins transport, session and screen contracts

### DW-178: The refresh rate has two writers and only one re-arms: ScreenStore.setRate() moves it and persists it without RefreshService.transition()
- source: spec-1-14-the-auto-refresh-framework.md | severity: low | fix-risk: med | footprint: in-epic
- evidence: ScreenStores is a useValue provider (main.ts), so any component can reach stores.for(d, r).setRate(n): the rate and the preference move, the chip re-reads it, and the timer keeps the old cadence or stays unarmed. ScreenStore.subscribe()/notify() exists for exactly this coupling and has no subscriber anywhere.
- 2026-09-13T02:25:57Z status=wontfix-accepted owner=2-4-the-data-table by=cr note=reopen_if=any call to ScreenStore.setRate outside RefreshService.setRate appears in ui/src (grep); today there is none

### DW-179: EXPERIENCE.md and epics.md disagree about the OAuth 2.0 screen's archetype, and the closed vocabulary makes the disagreement decide whether Story 6.4's exemption is honored or refused
- source: spec-1-15-classic-portal-fallback-links.md | severity: med | fix-risk: low | footprint: out-of-footprint
- evidence: EXPERIENCE.md :142 and :522 give it archetype list; epics.md :3325 calls its five tabs detail views. Pre-existing, but it now has a consequence: only a detail view may declare an exemption. The spec followed epics.md.
- 2026-09-13T03:56:03Z status=escalated owner=burndown by=harvest note=owner picks the published archetype; same family as DW-139
- 2026-09-13T04:46:13Z status=escalated owner=burndown by=cr note=prd.md:698 FR-44 also calls the five tabs detail views, so it is 2-1 against EXPERIENCE.md
- 2026-09-13T14:46:52Z status=by-design by=decision-sheet note=archetype is detail. EXPERIENCE.md amended at both :144 and :524; epics.md, prd.md FR-44 and AD-44's own single Release 1 exemption all require it, since only a detail view may declare one

### DW-180: The classic-link card's action label has no width bound, so a long declared classic page name wraps or overruns the fixed-height pill
- source: spec-1-15-classic-portal-fallback-links.md | severity: med | fix-risk: low | footprint: in-epic
- evidence: The DW-145 defect one card over: a bounded pill meeting an unbounded declared string.
- 2026-09-13T03:56:03Z status=routed owner=2-4-the-data-table by=harvest note=third sighting of bounded-container-meets-unbounded-string (DW-145, DW-173, this); 2.4 is the first story with real data-driven strings
- 2026-09-14T02:47:20Z owner=2-0-epic-1-deferred-cleanup by=x0 note=default-include: low fix-risk, lands before Epic 2 adds descriptors and actions in bulk
- 2026-09-14T04:31:22Z status=resolved-by:2-0-epic-1-deferred-cleanup by=adjudication note=classic-link card label bounded; classic-link-card.browser-spec.mjs pins the geometry in Chrome

### DW-181: The classic-link card duplicates instance-notice.ts's new-tab anchor, glyph escape included, with nothing keeping the copies in step
- source: spec-1-15-classic-portal-fallback-links.md | severity: low | fix-risk: low | footprint: in-epic
- evidence: Two hand-maintained copies of the same anchor markup.
- 2026-09-13T03:56:04Z status=wontfix-accepted owner=1-15-classic-portal-fallback-links by=harvest note=reopen_if=a third new-tab anchor ships, at which point the shared component pays for itself

### DW-182: A new-tab anchor gives assistive technology no indication that it opens a new tab, in the card and in the already-shipped instance notice
- source: spec-1-15-classic-portal-fallback-links.md | severity: low | fix-risk: low | footprint: in-epic
- evidence: Both anchors open a new tab with no announcement; the convention needs a published phrase, which EXPERIENCE.md does not carry.
- 2026-09-13T03:56:04Z status=wontfix-accepted owner=1-15-classic-portal-fallback-links by=harvest note=reopen_if=DW-126's decision sheet publishes an opens-in-a-new-tab phrase, at which point both anchors take it

### DW-183: screen-mirror.mjs's readSources() throws without naming the file when a descriptor's XData is valid UDL but invalid JSON
- source: spec-1-15-classic-portal-fallback-links.md | severity: low | fix-risk: low | footprint: in-epic
- evidence: The 'throws naming the file' guarantee the link-out check leans on holds for a missing block but not for a malformed one.
- 2026-09-13T03:56:04Z status=routed owner=2-3-one-descriptor-declared-read-serves-both-the-screen-and-its by=harvest note=2.3 adds descriptors in bulk, where a malformed XData becomes likely
- 2026-09-13T04:46:13Z occurrence=1-15-classic-portal-fallback-links
- 2026-09-13T04:46:13Z status=routed owner=2-3-one-descriptor-declared-read-serves-both-the-screen-and-its by=cr note=1.15's pin drives extractXData plus a bare JSON.parse, not readSources; closing this leaves it green
- 2026-09-14T02:47:20Z owner=2-0-epic-1-deferred-cleanup by=x0 note=default-include: low fix-risk, lands before Epic 2 adds descriptors and actions in bulk
- 2026-09-14T04:31:22Z status=resolved-by:2-0-epic-1-deferred-cleanup by=adjudication note=readSources names the .cls file and the parser message on invalid JSON; pinned at the checkClassicLinks gate in classic-links.test.mjs

### DW-184: The pre-commit hook runs classic-links.mjs but not screen-mirror.mjs --check, so a commit can land a descriptor change with the checked-in mirror stale while prebuild and prestart both refuse it
- source: spec-1-15-classic-portal-fallback-links.md | severity: med | fix-risk: low | footprint: in-epic
- evidence: ui/package.json's prebuild and prestart both chain 'node tools/screen-mirror.mjs --check && node tools/classic-links.mjs'; .githooks/pre-commit's OS_TRIGGER block dispatches check-objectscript.py, client-lint.mjs and classic-links.mjs only. The card renders from screens.generated.ts, which the hook therefore never re-derives. Caught at the next build, so no stale artifact ships.
- 2026-09-13T04:45:42Z status=routed owner=1-17-the-smoke-script-the-readiness-endpoint-and-ci by=cr note=one dispatch plus its pin; the hook comment already says the two scopes must agree
- 2026-09-13T15:59:59Z status=resolved-by:1-17-the-smoke-script-the-readiness-endpoint-and-ci by=adjudication note=.githooks/pre-commit now dispatches screen-mirror.mjs --check in the OS_TRIGGER block, so a descriptor change cannot land with the checked-in mirror stale

### DW-185: The classic-link card's action has no visible hover: .ocu-button-secondary:hover and .ocu-classic-link-card both resolve to --ocu-surface-container-low
- source: spec-1-15-classic-portal-fallback-links.md | severity: med | fix-risk: low | footprint: out-of-footprint
- evidence: _components.scss:276-279 sets the shared hover background to var(--ocu-surface-container-low); the new .ocu-classic-link-card sets the same token as its own background, so the state change is invisible on this one surface. The shipped :hover already diverged from DESIGN.md :546-554 (an 8% secondary state layer) before this story; this card is the first surface where it has a consequence. Not reachable in Release 1 -- nothing renders the card until 9.9.
- 2026-09-13T04:45:42Z status=routed owner=9-9-a-cut-editor-ships-reduced-never-half-working by=cr note=same owner and same first-render moment as DW-180 and DW-182
- 2026-09-14T02:47:20Z owner=2-0-epic-1-deferred-cleanup by=x0 note=default-include: low fix-risk, lands before Epic 2 adds descriptors and actions in bulk
- 2026-09-14T04:31:22Z status=resolved-by:2-0-epic-1-deferred-cleanup by=adjudication note=secondary and text button hover and pressed moved to DESIGN.md's 8%/12% secondary state layer; classic-link-card.browser-spec.mjs and design-tokens.test.mjs

### DW-186: The eight-refusal link-out rule is two hand-maintained copies with no mechanism keeping them in step, and only the JS copy runs in a gate; they already disagree on a JSON-numeric exempt flag
- source: spec-1-15-classic-portal-fallback-links.md | severity: med | fix-risk: med | footprint: out-of-footprint
- evidence: classic-links.mjs reads exemption.exempt === true; Base.ClassicLinkExempt() is ''..NestedField(...), and ''1 is 1 on this instance, so {"exempt": 1} is a half-made declaration to the build and an honored exemption to the registry. Each engine's corpus is a literal inside its own language's test and no test drives both, so a rule added to, removed from or reordered in one reddens nothing. The refusal sentences also differ (single vs double quotes; the unknown-archetype wording differs materially), which the I/O matrix calls 'the same sentence'. The build copy fails closed and is gated; Registry.Validate has no production caller.
- 2026-09-13T04:45:54Z status=escalated owner=burndown by=cr note=duplication is spec-bound (the Approach asks for both sides); a shared corpus is the design call
- 2026-09-13T21:00:47Z status=routed owner=2-6-the-users-list by=merge_gate note=owner-delegated decision: one shared JSON corpus both link-out engines read, a test per engine over it. Keep the ObjectScript copy - it runs on a customer instance where the build gate never ran. 2-6 declares classic links on a list archetype
- 2026-09-14T02:47:21Z owner=2-6-the-users-list by=x0 note=excluded: med fix-risk; one shared corpus for both engines is 2.6's link-out work
- 2026-09-14T18:21:33Z status=resolved-by:2-6-the-users-list by=adjudication note=one ClassicLinkCorpus read by Test/Descriptor.cls and classic-links.test.mjs; ClassicLinkProblem takes the parsed declaration; both engines refuse a non-boolean exempt with identical double-quoted sentences

### DW-187: The spine holds two ADs in tension: AD-27's Rule says every screen keeps FR-9's classic link, while AD-44's closed vocabulary makes an exemption impossible for 12 of the 16 archetypes
- source: spec-1-15-classic-portal-fallback-links.md | severity: med | fix-risk: med | footprint: out-of-footprint
- evidence: AD-27 Rule bullet 4 tracks FR-9's headline; prd.md:298's own consequence bullet says a list screen never links out and a detail view may, which is what AD-44 and this story implement. Archetype.cls classifies five keys list and seven none, and both engines refuse an exemption on all twelve. The story is correct against AD-44 and the PRD; AD-27's summary sentence is what no longer holds, and nothing records that.
- 2026-09-13T04:45:54Z status=escalated owner=burndown by=cr note=Rule 20 calls an AD-vs-AD conflict a re-architecture, not an amendment; owner decides at the decision sheet
- 2026-09-13T14:46:52Z status=by-design by=decision-sheet note=AD-44 and prd.md :298 win; AD-27's fourth bullet rewritten to say every screen declares its relationship to the classic page, which is the list-versus-detail rule, not a blanket link. The code was already right; the summary sentence was not

### DW-188: checkClassicLinks exits 0 clean when the descriptor directory holds only Base.cls, and QA's new test pins that as required behaviour
- source: spec-1-15-classic-portal-fallback-links.md | severity: low | fix-risk: low | footprint: in-story
- evidence: scanned 0 equals fileCount 0, so the equality guard is satisfied and there is no floor in the gated code -- the only scanned >= 1 assertion lives in a test. AC1 asks that the count be NAMED, not that zero be refused, and the run does print 'scanned 0 descriptor(s)', so a check that looked at nothing is distinguishable. Reachable only by deleting every descriptor, which breaks routing and the mirror loudly first.
- 2026-09-13T04:46:06Z status=wontfix-theoretical owner=burndown by=cr note=real if descriptors ever arrive from a source that can legitimately be empty at build time

### DW-189: ClassicLinkCard's title is a <p> inside a <section> with no accessible name, so the card is reachable by neither heading nor landmark navigation
- source: spec-1-15-classic-portal-fallback-links.md | severity: low | fix-risk: low | footprint: out-of-footprint
- evidence: classic-link-card.ts renders <section class=ocu-classic-link-card><p class=...-title>; screen-denied.ts titles its surface with <h1> and account-menu.ts/namespace-switch.ts name their panels with aria-labelledby. The right heading level depends on the page the card ends, which no consumer establishes until Story 9.9.
- 2026-09-13T04:46:06Z status=wontfix-accepted owner=9-9-a-cut-editor-ships-reduced-never-half-working by=cr note=reopen_if=Story 9.9 renders the card in a page and an axe or browser pass reports an unnamed region or a skipped heading level

### DW-190: ClassicLinkCard's present guard does not restate the same-origin constraint, so the render site trusts a predicate written in another language
- source: spec-1-15-classic-portal-fallback-links.md | severity: low | fix-risk: low | footprint: in-story
- evidence: present checks exempt, href and label but not that href is root-relative; AD-47 and AD-11 make the origin a trust boundary. Not reachable: the card reads screens.generated.ts, prebuild runs screen-mirror --check then classic-links and the hook runs classic-links, so neither a bad declaration nor a hand-edited mirror survives a build.
- 2026-09-13T04:46:06Z status=wontfix-theoretical owner=burndown by=cr note=real the moment a descriptor reaches the card from the API at runtime rather than from the build-time mirror

### DW-191: Uninstall and StateFingerprint now act against the caller's namespace rather than the resolved install namespace, and Uninstall is the only install entry point with no namespace guard
- source: spec-1-16-the-ipm-module-generated-from-one-roster.md | severity: med | fix-risk: med | footprint: in-story
- evidence: Every other entry point resolves the install namespace first; Uninstall does not, so it removes from wherever the caller happens to be. The move is also unpinned.
- 2026-09-13T07:18:53Z status=open owner=1-16-the-ipm-module-generated-from-one-roster by=harvest note=merged from two deferred items sharing one root cause
- 2026-09-13T08:23:41Z by=adjudication note=PINNED not fixed by QA: Test/InstallNamespaceSource asserts the current caller-namespace behaviour through the armed NamespaceProbe, so a future guard shows as a deliberate change rather than a surprise red. The guard itself is still open
- 2026-09-13T08:23:54Z status=routed owner=1-17-the-smoke-script-the-readiness-endpoint-and-ci by=adjudication note=install-path residue this story pinned but did not fix; 1.17 adds the third application through the same installer and is the last story of the epic that touches this code
- 2026-09-13T15:59:59Z status=resolved-by:1-17-the-smoke-script-the-readiness-endpoint-and-ci by=adjudication note=Uninstall and StateFingerprint act against the resolved install namespace, and Uninstall carries the same guard Install/StartPath/MarkInstalling use; pinned by Test.UninstallGuard

### DW-192: The roster is one source for the manifest half only: Names() resolves the keys 'shell' and 'api' literally, so a third roster application reaches module.xml but never Install()
- source: spec-1-16-the-ipm-module-generated-from-one-roster.md | severity: med | fix-risk: med | footprint: in-story
- evidence: This is the story's own thesis - one roster edit and no second edit - met for the generated manifest and not for the installer's key resolution. Story 1.17 adds the readiness application, which is exactly that third entry.
- 2026-09-13T07:18:53Z status=routed owner=1-17-the-smoke-script-the-readiness-endpoint-and-ci by=harvest note=merged from two deferred items; 1.17 adds the third application and will hit this immediately
- 2026-09-13T15:59:59Z status=resolved-by:1-17-the-smoke-script-the-readiness-endpoint-and-ci by=adjudication note=the installer, the generated manifest, StateFingerprint and the install-time assertion all iterate the roster. The readiness application arrived as one roster edit, which is the entry's own falsification

### DW-193: No test starts a gate or a container: prebuild, prestart, the pre-commit hook and the container start hook are asserted as source text, and the install namespace is only ever one of the two candidates
- source: spec-1-16-the-ipm-module-generated-from-one-roster.md | severity: med | fix-risk: med | footprint: in-epic
- evidence: Source-text assertions cannot catch a gate that runs but cannot fail, which this epic has now seen three times. OCUPILOT_NAMESPACE has never been set on a real container start.
- 2026-09-13T07:18:53Z status=routed owner=1-17-the-smoke-script-the-readiness-endpoint-and-ci by=harvest note=merged from two deferred items; 1.17 owns CI, where gates and containers are exercised for real
- 2026-09-13T15:59:59Z status=resolved-by:1-17-the-smoke-script-the-readiness-endpoint-and-ci by=adjudication note=CI executes prebuild, prestart, the pre-commit checkers and the container start hook rather than asserting them as source text, and ci.test.mjs pins the wiring. The install namespace is exercised beyond the two candidates by the system-namespace refusal (DW-195)

### DW-194: WantFromRoster's three refusal branches, ApplicationFingerprint's NOPROPERTIES guard, and the demo-fixture namespace fix have no pinning test
- source: spec-1-16-the-ipm-module-generated-from-one-roster.md | severity: med | fix-risk: low | footprint: in-story
- evidence: Three refusal paths and one correction ship unexercised.
- 2026-09-13T07:18:53Z status=open owner=1-16-the-ipm-module-generated-from-one-roster by=harvest note=merged from two deferred items
- 2026-09-13T08:23:41Z status=resolved-by:1-16-the-ipm-module-generated-from-one-roster by=adjudication note=QA added Test/RosterWant (WantFromRoster's three refusals, ApplicationFingerprint's NOPROPERTIES) and Test/InstallNamespaceSource (the demo-fixture namespace fix); the review re-verified them live and corrected one recorded consequence

### DW-195: An OCUPILOT_NAMESPACE naming a system namespace compiles the whole source tree into it before StartPath refuses
- source: spec-1-16-the-ipm-module-generated-from-one-roster.md | severity: med | fix-risk: med | footprint: in-story
- evidence: The refusal is correct but late: the compile has already happened by the time it fires, leaving OcuPilot's classes in a namespace it then declines to install into.
- 2026-09-13T07:18:53Z status=open owner=1-16-the-ipm-module-generated-from-one-roster by=harvest note=
- 2026-09-13T08:23:41Z by=adjudication note=PINNED not fixed: ui/tools/compose.test.mjs asserts LoadDir runs before StartPath's namespace guard, so a fix is visible rather than silently absorbed
- 2026-09-13T08:23:54Z status=routed owner=1-17-the-smoke-script-the-readiness-endpoint-and-ci by=adjudication note=install-path residue this story pinned but did not fix; 1.17 adds the third application through the same installer and is the last story of the epic that touches this code
- 2026-09-13T15:59:59Z status=resolved-by:1-17-the-smoke-script-the-readiness-endpoint-and-ci by=adjudication note=scripts/container-start.sh resolves and refuses a system namespace in an earlier %SYS session, before LoadDir compiles anything; exit 1 with no classes compiled

### DW-196: The pre-commit checks read the working tree, not the index, so a partially staged roster and manifest pair passes the hook
- source: spec-1-16-the-ipm-module-generated-from-one-roster.md | severity: med | fix-risk: low | footprint: in-epic
- evidence: The hook proves the working tree is consistent, not the commit. Every gate this epic added shares the shape.
- 2026-09-13T07:18:53Z status=routed owner=1-17-the-smoke-script-the-readiness-endpoint-and-ci by=harvest note=1.17 owns CI, which is where an index-versus-worktree gate is settled for all of them
- 2026-09-13T15:59:59Z status=by-design by=adjudication note=deliberate and now stated at .githooks/pre-commit:3-10. The hook triggers on staged paths and its checkers read the working tree: a half-staged pair is caught because both halves are on disk, while a staged fix for an unstaged cause passes here and fails in CI. CI is the gate over what was committed; this hook is the fast one before it

### DW-197: The generated module.xml is never validated as well-formed XML beyond its comments
- source: spec-1-16-the-ipm-module-generated-from-one-roster.md | severity: med | fix-risk: low | footprint: in-story
- evidence: The generator writes text and the checker compares text; neither parses it.
- 2026-09-13T07:18:53Z status=open owner=1-16-the-ipm-module-generated-from-one-roster by=harvest note=a parse step is small and would catch a class of generator defect the string compare cannot
- 2026-09-13T08:23:54Z status=routed owner=1-17-the-smoke-script-the-readiness-endpoint-and-ci by=adjudication note=install-path residue this story pinned but did not fix; 1.17 adds the third application through the same installer and is the last story of the epic that touches this code
- 2026-09-13T15:59:59Z status=resolved-by:1-17-the-smoke-script-the-readiness-endpoint-and-ci by=adjudication note=ui/tools/ipm-manifest.mjs parses the generated module.xml as XML and refuses naming the parse error and offset; the build reports parsed 16 XML element(s)

### DW-198: On the IPM path the gateway-gap report says no web application was created, on the one install where two were
- source: spec-1-16-the-ipm-module-generated-from-one-roster.md | severity: med | fix-risk: low | footprint: in-story
- evidence: The report reads the created-apps array, which the IPM path does not fill because FileCopy places the bundle instead.
- 2026-09-13T07:18:53Z status=open owner=1-16-the-ipm-module-generated-from-one-roster by=harvest note=
- 2026-09-13T08:23:41Z by=adjudication note=PINNED not fixed: Test/GatewayGapIpmPath asserts the current misleading message for an empty pCreatedApps, making it a deliberate visible fact
- 2026-09-13T08:23:54Z status=routed owner=1-17-the-smoke-script-the-readiness-endpoint-and-ci by=adjudication note=install-path residue this story pinned but did not fix; 1.17 adds the third application through the same installer and is the last story of the epic that touches this code
- 2026-09-13T15:59:59Z status=resolved-by:1-17-the-smoke-script-the-readiness-endpoint-and-ci by=adjudication note=ReportGatewayGap takes the install profile and reports per application, so the IPM path no longer says no web application was created on the one install where two were

### DW-199: An application's Description is set on create only, never repaired, and is in neither AssertedProperties nor StateFingerprint
- source: spec-1-16-the-ipm-module-generated-from-one-roster.md | severity: med | fix-risk: low | footprint: in-story
- evidence: Drift repair covers every other property; the description silently keeps whatever it was created with.
- 2026-09-13T07:19:08Z status=open owner=1-16-the-ipm-module-generated-from-one-roster by=harvest note=
- 2026-09-13T08:23:54Z status=routed owner=1-17-the-smoke-script-the-readiness-endpoint-and-ci by=adjudication note=install-path residue this story pinned but did not fix; 1.17 adds the third application through the same installer and is the last story of the epic that touches this code
- 2026-09-13T15:59:59Z status=resolved-by:1-17-the-smoke-script-the-readiness-endpoint-and-ci by=adjudication note=Description is carried in the asserted manifest, compared against the instance and repaired on the next install like every other asserted property, rather than set on create only

### DW-200: A non-string or mis-cased resource.scope in the roster is emitted verbatim or dropped, with no roster-shape refusal
- source: spec-1-16-the-ipm-module-generated-from-one-roster.md | severity: low | fix-risk: low | footprint: in-story
- evidence: The roster is now a source of truth with no schema check of its own.
- 2026-09-13T07:19:08Z status=wontfix-accepted owner=1-16-the-ipm-module-generated-from-one-roster by=harvest note=reopen_if=a third consumer reads the roster, at which point a shape refusal pays for itself

### DW-201: container-start.sh refuses a malformed OCUPILOT_NAMESPACE while container-health.sh silently uses the sanitized remainder
- source: spec-1-16-the-ipm-module-generated-from-one-roster.md | severity: low | fix-risk: low | footprint: in-story
- evidence: Two scripts sanitize the same input and disagree about what to do with a bad one.
- 2026-09-13T07:19:08Z status=wontfix-accepted owner=1-16-the-ipm-module-generated-from-one-roster by=harvest note=reopen_if=OCUPILOT_NAMESPACE is ever set in a shipped compose file or documented for operators
- 2026-09-13T08:19:22Z status=wontfix-accepted owner=1-16-the-ipm-module-generated-from-one-roster by=cr note=occurrence: container-health.sh also has no namespace-existence check where container-start.sh does

### DW-202: An unreadable /proc/1/environ makes container-start.sh treat OCUPILOT_NAMESPACE as absent and fall back silently
- source: spec-1-16-the-ipm-module-generated-from-one-roster.md | severity: low | fix-risk: low | footprint: in-story
- evidence: A read failure and an unset variable are indistinguishable to the caller.
- 2026-09-13T07:19:08Z status=wontfix-accepted owner=1-16-the-ipm-module-generated-from-one-roster by=harvest note=reopen_if=OCUPILOT_NAMESPACE becomes a supported operator setting rather than an undocumented override

### DW-203: docker-compose.yml carries no OCUPILOT_NAMESPACE placeholder beside OCUPILOT_DEMO
- source: spec-1-16-the-ipm-module-generated-from-one-roster.md | severity: low | fix-risk: low | footprint: in-story
- evidence: The override exists and is honoured but is discoverable only by reading the start script.
- 2026-09-13T07:19:08Z status=wontfix-accepted owner=1-16-the-ipm-module-generated-from-one-roster by=harvest note=reopen_if=the override is documented for operators, at which point the compose file should show it commented out

### DW-204: extractXData counts braces per line without understanding JSON strings, so a brace inside a string value would end the block early
- source: spec-1-16-the-ipm-module-generated-from-one-roster.md | severity: low | fix-risk: low | footprint: in-epic
- evidence: Three readers now depend on extractXData; none of today's descriptors or the roster carry a braced string.
- 2026-09-13T07:19:08Z status=routed owner=2-3-one-descriptor-declared-read-serves-both-the-screen-and-its by=harvest note=2.3 adds descriptors in bulk, where a braced string value becomes likely; same file as DW-183
- 2026-09-14T02:47:20Z owner=2-0-epic-1-deferred-cleanup by=x0 note=default-include: low fix-risk, lands before Epic 2 adds descriptors and actions in bulk
- 2026-09-14T04:31:22Z status=resolved-by:2-0-epic-1-deferred-cleanup by=adjudication note=string-aware brace counting in screen-mirror.mjs extractXData and check-objectscript.py brace_delta; pinned by screen-mirror.test.mjs and test_check_objectscript.py, with a cross-reader agreement test

### DW-205: WantFromRoster and ApplicationFingerprint lost [ Private ] for testability when OcuPilot.Test.InstallerProbe, a subclass that already overrides a Private method, was an available seam
- source: spec-1-16-the-ipm-module-generated-from-one-roster.md | severity: low | fix-risk: med | footprint: in-story
- evidence: InstallerProbe Extends OcuPilot.Install.Installer and already overrides the Private CreateDemoFixtures, so a test-only wrapper there would have reached both methods without widening the installer's public surface.
- 2026-09-13T08:18:58Z status=wontfix-accepted owner=1-16-the-ipm-module-generated-from-one-roster by=cr note=reopen_if=any caller outside OcuPilot.Test.* calls WantFromRoster or ApplicationFingerprint

### DW-206: Nothing marks the install gate installing on the IPM path, and IPM enables both web applications before Install() runs (AD-38)
- source: spec-1-16-the-ipm-module-generated-from-one-roster.md | severity: med | fix-risk: high | footprint: in-story
- evidence: MarkInstalling is called only from container-start.sh:168 and module.xml carries one <Invoke> (Roster models invoke as an object, not a list), so GateStatus reads installed through IPM's Compile phase, which recompiles every OcuPilot class; the Enabled=1 WebApplication elements also run in Activate before the When=After Invoke. A Compile/Before Invoke cannot mark on a first IPM install -- the class is not compiled yet -- so any fix needs a live throwaway IPM run to settle.
- 2026-09-13T08:19:22Z status=escalated owner=burndown by=cr note=AD-38's mark clause is written for the container start path and tolerates a start that cannot mark; IPM is a new path outside it
- 2026-09-13T14:46:52Z status=wontfix-accepted by=decision-sheet note=AD-38 extended: the mark is best effort on every path, not only the container's. The IPM window is accepted for Release 1 because IPM is a distribution channel and the container is the shipped install path (AD-18). An IPM-native marking step is chartered, not assumed

### DW-207: RosterNames' non-absolute-path and empty-asserted-set refusals -- the guard the corrected docs name as the real anti-vacuity protection -- are exercised by nothing
- source: spec-1-16-the-ipm-module-generated-from-one-roster.md | severity: med | fix-risk: high | footprint: in-story
- evidence: RosterNames is Private and builds pNames through a hard ##class(OcuPilot.Install.Roster).Application call, so no subclass seam can hand it a roster it did not ship; deleting either refusal leaves the whole suite green because the shipped roster never resolves an empty set or a relative path. The JavaScript half of both rules is now covered -- this review added an ipm-manifest refusal for each.
- 2026-09-13T08:19:22Z status=escalated owner=burndown by=cr note=closing it needs an overridable roster seam on the production installer, which a review may not add
- 2026-09-13T21:01:00Z status=routed owner=burndown by=merge_gate note=owner-delegated decision (sheet D3): add an overridable roster seam on the production installer so both RosterNames refusals are exercised
- 2026-09-13T21:01:57Z owner=1-18-epic-1-burn-down by=burndown note=chartered into the Epic 1 burn-down story, risk-led rather than sort-led: first-install and silent-refusal defects, release-blocking licence distribution, then CI reliability and vacuous pins
- 2026-09-14T00:42:24Z status=resolved-by:1-18-epic-1-burn-down by=adjudication note=overridable roster seam on the production installer; both RosterNames refusals are now exercised by calling code

### DW-208: OcuPilot.Test.GatewayGapIpmPath's only assertion is already made by Test/WebApp.cls, and nothing in the class touches the IPM path it is named for
- source: spec-1-16-the-ipm-module-generated-from-one-roster.md | severity: low | fix-risk: low | footprint: in-story
- evidence: WebApp.cls:439 already asserts the same 'This install run created no web application' string through a full repeat install, so the class's named mutation was red before the class was written; DW-198's actual shape -- two applications created by IPM's own WebApplication elements in the same Activate phase -- stays unobserved.
- 2026-09-13T08:19:22Z status=wontfix-accepted owner=1-16-the-ipm-module-generated-from-one-roster by=cr note=reopen_if=DW-198 is fixed and only one of the two assertions goes red

### DW-209: Roster.Get discards IDKEYOpen's status and reports every failure as 'the XData block is missing'; AssertedProperties swallows everything in a bare Catch
- source: spec-1-16-the-ipm-module-generated-from-one-roster.md | severity: low | fix-risk: low | footprint: in-story
- evidence: Get passes .tOpenSC and never reads it, so a parse or permission failure is reported as an absent block; both mask the real cause in the one class all three roster consumers depend on.
- 2026-09-13T08:19:22Z status=wontfix-accepted owner=1-16-the-ipm-module-generated-from-one-roster by=cr note=reopen_if=a roster read fails in the field and the message sends the reader to a block that is present

### DW-210: bundle.destinationTemplate is a stored literal rather than generated from the roster by the normalization rule the Design Notes named as the fallback
- source: spec-1-16-the-ipm-module-generated-from-one-roster.md | severity: low | fix-risk: med | footprint: in-story
- evidence: The Design Notes' fallback was 'generated from the roster by the same normalization rule'; the roster declares the expanded string instead. The Spec Change Log records the decision, and Test/Manifest.TestBundleDestinationIsTheHandlersOwnAnswer expands it live against RootDirectory -- the pin the same sentence offered as the mitigation.
- 2026-09-13T08:19:22Z status=by-design owner=1-16-the-ipm-module-generated-from-one-roster by=cr note=spec-bound: Spec Change Log entry 1; this review's P4 patch removed the third copy by holding destinationApplication to a declared application path

### DW-211: IPMVersion=">=0.10.0" is a floor while NFR-13 reads 'IPM 0.10.x', and the spec's Rule-5 note asserts the two are equivalent
- source: spec-1-16-the-ipm-module-generated-from-one-roster.md | severity: low | fix-risk: low | footprint: in-story
- evidence: >=0.10.0 admits 0.11 and 1.0; the spec's Execution task states the expression verbatim, so the code matches the spec and the imprecision is in the equivalence claim, not the manifest.
- 2026-09-13T08:19:22Z status=by-design owner=1-16-the-ipm-module-generated-from-one-roster by=cr note=spec-bound: changing it edits an Execution task, and an upper bound is unverified against %IPM.Storage.SystemRequirements

### DW-212: rosterShapeProblem accepts two applications sharing a key or a path, and Roster.Application silently answers the first
- source: spec-1-16-the-ipm-module-generated-from-one-roster.md | severity: low | fix-risk: low | footprint: in-story
- evidence: The roster is committed and byte-compared against the manifest, so the blast radius is one reviewed edit, and no roster has ever carried a duplicate.
- 2026-09-13T08:19:22Z status=wontfix-theoretical owner=1-16-the-ipm-module-generated-from-one-roster by=cr note=would become real the first time an application entry is added by copying an existing one and only half-edited

### DW-213: Fixture.Create's namespace fix is pinned by a source-text assertion read from the INSTANCE's compiled copy, so an uncompiled edit leaves it green
- source: spec-1-16-the-ipm-module-generated-from-one-roster.md | severity: med | fix-risk: high | footprint: in-story
- evidence: Test/InstallNamespaceSource:TestFixtureCreateUsesTheCallersNamespaceNotTheResolvedDefault never calls Create: it reads the class back with %Compiler.UDL.TextServices.GetTextAsString and asserts a substring, so any rewrite reaching the wrong namespace without touching that literal stays green, and the subject is the instance's compiled source rather than the committed file. NamespaceProbe cannot reach it -- Fixture calls ##class(Installer).ResolveNamespace() directly -- and the repository is not mounted into the instance.
- 2026-09-13T08:20:29Z status=escalated owner=burndown by=cr note=needs a Fixture namespace seam or the container run DW-193 routes to 1.17; a general property of every source-text pin in this suite
- 2026-09-13T21:01:00Z status=routed owner=burndown by=merge_gate note=owner-delegated decision (sheet D4): a Fixture namespace seam that lets a test call Create, replacing the source-text pin read from the instance's compiled copy; sweep the suite for other source-text pins of that shape
- 2026-09-13T21:01:57Z owner=1-18-epic-1-burn-down by=burndown note=chartered into the Epic 1 burn-down story, risk-led rather than sort-led: first-install and silent-refusal defects, release-blocking licence distribution, then CI reliability and vacuous pins
- 2026-09-14T00:42:24Z status=resolved-by:1-18-epic-1-burn-down by=adjudication note=Fixture.Create takes a namespace argument so the fix is exercised by a call, replacing the source-text pin read from the compiled copy; the sweep found one other source-text pin (UnexpireScope) kept with its reason

### DW-214: CI's npx puppeteer browsers install chrome is the one gate command never executed as written
- source: spec-1-17-the-smoke-script-the-readiness-endpoint-and-ci.md | severity: low | fix-risk: low | footprint: in-story
- evidence: This sandbox's puppeteer download extracts without its Frameworks directory, so the browser spec was verified against a system Chrome through OCUPILOT_BROWSER_EXECUTABLE. The spec and its throwaway are verified 4/4 and red under a layout mutation; unverified is that the pinned download works on a Linux runner. Surfaces as a failed install step on the workflow's first real run
- 2026-09-13T14:48:40Z status=routed owner=burndown by=harvest note=harvested at dev_complete; inherently unverifiable until a workflow runs on GitHub Actions
- 2026-09-13T18:10:43Z status=resolved-by:1-17-the-smoke-script-the-readiness-endpoint-and-ci by=burndown note=closed by evidence: CI run 34773625932/34773637146 on ubuntu-latest ran 'npx puppeteer browsers install chrome' as written and the step concluded success. The one gate command never executed as written has now executed as written

### DW-215: lint-docs.sh runs an unpinned npx markdownlint-cli2 while every other tool CI runs is pinned exactly
- source: spec-1-17-the-smoke-script-the-readiness-endpoint-and-ci.md | severity: med | fix-risk: low | footprint: out-of-footprint
- evidence: scripts/lint-docs.sh:31. Pre-existing and not in 1.17's diff, but CI now runs it on every change, so a markdownlint-cli2 release can turn the document gate red with no change to this repository. puppeteer 24.24.0, typescript 6.0.3, Node 22.22.3 and the 2026.2 image tag are all pinned and ci.test.mjs asserts those pins
- 2026-09-13T14:48:40Z status=routed owner=burndown by=harvest note=harvested at dev_complete; one-line pin plus a ci.test.mjs assertion alongside the others
- 2026-09-13T21:01:57Z owner=1-18-epic-1-burn-down by=burndown note=chartered into the Epic 1 burn-down story, risk-led rather than sort-led: first-install and silent-refusal defects, release-blocking licence distribution, then CI reliability and vacuous pins
- 2026-09-14T00:42:24Z status=resolved-by:1-18-epic-1-burn-down by=adjudication note=lint-docs.sh pins markdownlint-cli2@0.23.2

### DW-216: Install.Smoke.Port assumes the OcuPilot applications answer on the instance's own configured web-server port at localhost
- source: spec-1-17-the-smoke-script-the-readiness-endpoint-and-ci.md | severity: med | fix-risk: med | footprint: in-story
- evidence: src/OcuPilot/Install/Smoke.cls (Port). For an instance fronted by an external Web Gateway -- the normal production shape -- Config.Startup.WebServerPort is not where /ocupilot answers, so every HTTP check fails on a correctly installed instance. The class ships and is offered to operators, and the constraint is documented nowhere. Not reachable from CI or Epic 17, which both drive a container serving its own port
- 2026-09-13T14:48:40Z status=routed owner=burndown by=harvest note=harvested at dev_complete; needs a documented constraint at minimum, an override at best
- 2026-09-13T21:00:47Z status=routed owner=17-2-a-readme-whose-install-steps-work-the-first-time by=burndown note=Smoke.Port assumes the instance's own web-server port, so every HTTP check fails behind an external Web Gateway. 17-2 owns install instructions that work on a real deployment shape

### DW-217: The npm third-party licence file is generated by the build and never distributed
- source: spec-1-17-the-smoke-script-the-readiness-endpoint-and-ci.md (cr) | severity: med | fix-risk: low | footprint: in-epic
- evidence: angular.json emits dist/ocupilot-ui/3rdpartylicenses.txt one directory ABOVE the served root, and module.xml's only <FileCopy Name="ui/dist/ocupilot-ui/browser/"> copies the served root. So the installed bundle and the IPM package ship minified third-party code with no notice file. ATTRIBUTIONS.md (853a8a6) closes the font half by an angular.json assets entry and states this half as a location rather than a gap.
- 2026-09-13T15:54:21Z status=escalated owner=burndown by=cr note=owner's call: an assets entry landing it inside browser/, or a second FileCopy; either changes what ships
- 2026-09-13T21:00:47Z status=routed owner=burndown by=merge_gate note=owner-delegated decision: distribute 3rdpartylicenses.txt inside the served root (an angular.json assets or outputPath change so it lands in browser/, which module.xml FileCopy already carries). Public release is 2026-09-24, so this goes in the burn-down story, not later
- 2026-09-13T21:01:57Z owner=1-18-epic-1-burn-down by=burndown note=chartered into the Epic 1 burn-down story, risk-led rather than sort-led: first-install and silent-refusal defects, release-blocking licence distribution, then CI reliability and vacuous pins
- 2026-09-14T00:42:24Z status=resolved-by:1-18-epic-1-burn-down by=adjudication note=postbuild runs tools/licenses.mjs, so a real build lands 3rdpartylicenses.txt inside browser/ which module.xml FileCopy carries; licence.browser-spec.mjs (QA) checks the real build's bytes are served by a real installed throwaway

### DW-218: CI's Python interpreter is the one tool in the workflow that is not pinned
- source: spec-1-17-the-smoke-script-the-readiness-endpoint-and-ci.md (cr) | severity: med | fix-risk: low | footprint: in-story
- evidence: ci.yml pins Node 22.22.3, TypeScript 6.0.3, puppeteer 24.24.0 and the 2026.2 image tag exactly and ci.test.mjs asserts each pin, while the two 'uv run' gates take whatever interpreter uv resolves on the runner: there is no pyproject.toml, no .python-version and no PEP-723 block in either script. Same class as the already-deferred unpinned markdownlint-cli2, which the spec records and this one it does not.
- 2026-09-13T15:54:21Z status=escalated owner=burndown by=cr note=which version to pin is the owner's call; setup-uv takes a python-version input, so the fix is two lines once chosen
- 2026-09-13T21:00:47Z status=routed owner=burndown by=merge_gate note=owner-delegated decision: pin CI's Python/uv interpreter like every other tool, asserted in ci.test.mjs. Burn-down story, with DW-215
- 2026-09-13T21:01:57Z owner=1-18-epic-1-burn-down by=burndown note=chartered into the Epic 1 burn-down story, risk-led rather than sort-led: first-install and silent-refusal defects, release-blocking licence distribution, then CI reliability and vacuous pins
- 2026-09-14T00:42:24Z status=resolved-by:1-18-epic-1-burn-down by=adjudication note=Python pinned to 3.12.14 via .python-version and uv to 0.12.9, asserted in ci.test.mjs; actions re-pinned by SHA to their node24 releases in review (DW-238)

### DW-219: Uninstall's contract on an instance OcuPilot does not wholly own has three half-state paths
- source: spec-1-17-the-smoke-script-the-readiness-endpoint-and-ci.md (cr) | severity: med | fix-risk: med | footprint: in-story
- evidence: Three, same root cause. (1) the bundle directory is removed unconditionally, so an adopted /ocupilot that uninstall deliberately KEEPS is left answering 503 STATIC.NOBUNDLE. (2) an unreadable provenance record logs a warn and continues, removing database, mapping, admin role, admin resource, audit event and bundle while every web application survives pointing at a deleted code database. (3) a declared matching role whose application was already gone is now never removed, so AnyObjectExists keeps answering 1 for that profile.
- 2026-09-13T15:54:21Z status=escalated owner=burndown by=cr note=each has two defensible semantics (keep vs remove, refuse vs continue); DW-94's own HIGH came from guessing one
- 2026-09-13T21:00:47Z status=routed owner=18-13-multi-namespace-install by=merge_gate note=owner-delegated decision: resolve Uninstall's three half-state paths on an instance OcuPilot does not wholly own. 18-13 is the story where OcuPilot shares an instance with other installs

### DW-220: The DW-94 acceptance criterion and its I-O matrix row state a contract the installer deliberately does not have
- source: spec-1-17-the-smoke-script-the-readiness-endpoint-and-ci.md (cr) | severity: med | fix-risk: low | footprint: in-epic
- evidence: The AC bullet and the matrix row both read 'exists with no provenance row -> install refuses, creates and repairs nothing'. The shipped installer refuses only when the unrecorded application ALSO dispatches to a class other than the roster's; one carrying the declared class is recorded adopted and repaired, which is correct and necessary (this repository's own container, and every IPM install). The divergence is reasoned in ## Spec Change Log and was filed and rejected by three reviewers; the acceptance text was never corrected at its origin.
- 2026-09-13T15:54:21Z status=routed owner=burndown by=cr note=Rule 5 apply-and-report: a two-line correction to the AC bullet and the matrix row, the lead's to make
- 2026-09-13T21:02:22Z status=resolved-by:1-17-the-smoke-script-the-readiness-endpoint-and-ci by=burndown note=corrected at origin: the spec's I/O matrix row now states the delivered contract - refuse only when there is no provenance row AND the application dispatches to a class other than the declared one; adopt and repair otherwise. The epics.md bullet already said did-not-create and needed no change

### DW-221: The spine's Stack table carries no row for the pinned browser harness
- source: spec-1-17-the-smoke-script-the-readiness-endpoint-and-ci.md (cr) | severity: med | fix-risk: low | footprint: in-epic
- evidence: Story 1.17 pins puppeteer 24.24.0 exactly as a devDependency and ci.test.mjs asserts the pin, and DW-159's back-fill is chartered to build on it. Rule 20 puts a pinned dependency in the spine's Stack table at the moment it is decided; the table's newest rows are from 2026-09-09 and name neither it nor vitest/jsdom.
- 2026-09-13T15:54:21Z status=routed owner=burndown by=cr note=one Stack row, written by the lead; the plan stage reads the spine, not package.json
- 2026-09-13T21:02:22Z status=resolved-by:1-17-the-smoke-script-the-readiness-endpoint-and-ci by=burndown note=spine Stack table gains rows for the client test runners (node --test, the vitest+jsdom component runner, the pinned puppeteer headless Chrome) and for CI's three jobs, all delivered by 1.17

### DW-222: DW-108's accessibility changes and DW-163's server-flag disclosure are observed by no executing assertion
- source: epic-1-decision-sheet.md 853a8a6 (cr) | severity: med | fix-risk: low | footprint: in-epic
- evidence: instance-notice.ts gained role=alert, tabindex=-1, two h1s and an afterNextRender focus move; sign-in.ts gained two role=status banners; server-flag.ts gained an unbounded input with two [data-unbounded] style rules and one host setting it. grep over ui/src and ui/tools finds no assertion on any role, on document.activeElement for these components, or on the attribute -- and session.test.mjs's opening-tag regex was deliberately LOOSENED in the same commit. Deleting every one of them leaves 582 tools tests and 184 component tests green. Related: app.spec.ts's querySelector('[role="alert"]') is no longer unique in the checking state.
- 2026-09-13T15:54:47Z status=routed owner=burndown by=cr note=an instance-notice.spec.ts plus two role assertions and one attribute assertion; the sheet records A7 and A8 as implemented
- 2026-09-13T21:01:57Z owner=1-18-epic-1-burn-down by=burndown note=chartered into the Epic 1 burn-down story, risk-led rather than sort-led: first-install and silent-refusal defects, release-blocking licence distribution, then CI reliability and vacuous pins
- 2026-09-14T00:42:24Z status=resolved-by:1-18-epic-1-burn-down by=adjudication note=sign-in.spec.ts asserts the signed-out and session-ended banners are polite status regions and never alerts; the server-flag disclosure has an executing assertion

### DW-223: The decision sheet's twelve chartered entries reach no gate: no ledger trailer, no sprint key, stale census
- source: epic-1-decision-sheet.md 853a8a6 (cr) | severity: med | fix-risk: low | footprint: in-epic
- evidence: The sheet says twelve entries are chartered into Story 1.18 and that 'the decision recorded for each is the option letter above'. Checked DW-96, DW-49, DW-126, DW-32, DW-44: all still end at escalated/decision-pending owner=burndown with no 2026-09-13 trailer, while all fifteen implemented entries did get one. sprint-status.yaml has no 1-18 key at all. The sheet's own basis line says 213 entries; the same commit takes the file to 216. Rule 17 (1): an entry no gate can reach is worse than a halt.
- 2026-09-13T15:54:47Z status=routed owner=burndown by=cr note=lead bookkeeping before epic_status_done: trailers, the 1.18 charter, and the census line
- 2026-09-13T21:02:23Z status=resolved-by:1-18-epic-1-burn-down by=burndown note=closed by this gate: every sheet-decided entry now carries a by=merge_gate trailer, the burn-down story has a sprint key, and each chartered or overflowed entry has a DW-n bullet in its receiving story's epics.md block

### DW-224: ci-unit-test.sh's helper exclusion reads inherited compiled methods
- source: spec-1-17-the-smoke-script-the-readiness-endpoint-and-ci.md (cr) | severity: low | fix-risk: low | footprint: in-story
- evidence: The --list query excludes a class with no Test* method via EXISTS over %Dictionary.CompiledMethod, which carries inherited rows: probed live, OcuPilot.Test.Http has 95 rows, 88 inherited. The exclusion holds only while no ancestor declares a Test* method. No such base class exists today.
- 2026-09-13T15:54:47Z status=wontfix-accepted owner=burndown by=cr note=reopen_if=a shared OcuPilot test base class declaring a Test* method is added and ci-runner reddens over a helper

### DW-225: CI runs the full three-job set twice for every pull-request commit
- source: spec-1-17-the-smoke-script-the-readiness-endpoint-and-ci.md (cr) | severity: low | fix-risk: low | footprint: in-story
- evidence: on: push has no branch or path filter and pull_request is declared beside it; the concurrency group keys on github.ref, which differs between the two events, so neither cancels the other. A documentation-only commit on a PR branch spends the 45-minute instance job and both 30-minute images jobs twice.
- 2026-09-13T15:54:47Z status=wontfix-accepted owner=burndown by=cr note=reopen_if=the first real runs show duplicate jobs the owner minds; narrowing push to trunk branches is a product call, not a fix

### DW-226: ReportGatewayGap's defaulted profile makes a future one-argument caller mark production
- source: spec-1-17-the-smoke-script-the-readiness-endpoint-and-ci.md (cr) | severity: low | fix-risk: low | footprint: in-story
- evidence: The second parameter changed from ByRef pCreatedApps to pProfile As %String = "" and the method gained a write (GuardedMarkGatewayReported on every unreported row). Both legacy test callers were corrected to pass "probe" at review; the default means the NEXT one-argument caller silently reads and marks the production profile, where the old signature made that call harmless.
- 2026-09-13T15:54:47Z status=wontfix-accepted owner=burndown by=cr note=reopen_if=a one-argument call to ReportGatewayGap appears anywhere in src/OcuPilot/

### DW-227: Install.Smoke's roster-path guards and Roster.Keys's key shape have no dedicated test
- source: spec-1-17-the-smoke-script-the-readiness-endpoint-and-ci.md (cr) | severity: low | fix-risk: low | footprint: in-story
- evidence: The five checks now each refuse an unreadable roster by name, and the fail-closed outcome vocabulary is pinned by Test.Smoke; the five guards themselves are not, because no seam drives RosterPath to "" without new public surface. Separately, applicationShapeProblem validates path, manifest, installer and matchRole and never key, so a roster key containing a comma would split into two empty lookups.
- 2026-09-13T15:54:47Z status=wontfix-theoretical owner=burndown by=cr note=both need an unreadable or hand-corrupted roster, which is source-controlled and gated by ipm-manifest --check

### DW-228: The spec scopes scripts/smoke.sh to throwaway containers, but the per-story smoke gate runs it against the live instance and it mints a token pair
- source: spec-1-17-the-smoke-script-the-readiness-endpoint-and-ci.md (code review, rework 1) | severity: med | fix-risk: med | footprint: out-of-footprint
- evidence: Spec ## Verification lists the smoke script as throwaway-only; /epic-cycle's per-story smoke gate ran it as --container ocupilot, and Install/Smoke.cls:296 POSTs /login and mints an access+refresh pair that nothing signs out. The two rules contradict each other and neither side was amended.
- 2026-09-13T16:30:06Z status=escalated owner=burndown by=cr note=reconcile the throwaway-only line with the gate that must run it live; decide whether an orphan session is acceptable
- 2026-09-13T21:00:47Z status=routed owner=burndown by=merge_gate note=owner-delegated decision: smoke.sh signs out the token pair it mints, and the spec's throwaway-only scope is amended to say the per-story smoke gate runs it live. Every lead smoke currently leaks one session onto the live instance - across ~200 stories that accumulates
- 2026-09-13T21:01:57Z owner=1-18-epic-1-burn-down by=burndown note=chartered into the Epic 1 burn-down story, risk-led rather than sort-led: first-install and silent-refusal defects, release-blocking licence distribution, then CI reliability and vacuous pins
- 2026-09-14T00:42:24Z status=resolved-by:1-18-epic-1-burn-down by=adjudication note=smoke.sh signs out the pair it mints; Test.Smoke pins the 401 rule and the sign-out of an accepted refresh via SmokeRefreshFault. Live lead smoke reports sign-out passed

### DW-229: Four shell gates are pinned as text only and CI runs no shell syntax check, which is how the credential guard shipped broken
- source: spec-1-17-the-smoke-script-the-readiness-endpoint-and-ci.md (code review, rework 1) | severity: med | fix-risk: low | footprint: out-of-footprint
- evidence: smoke.sh's credential guard read as a newline test and was *""* -- a text pin cannot see that, and only an executing test found it. wait-readiness.sh, ci-throwaway.sh, ci-image-compile.sh and container-health.sh are still asserted as text only, and none of ci.yml's fifteen run: gates is sh -n or shellcheck.
- 2026-09-13T16:30:12Z status=routed owner=burndown by=cr note=an sh -n or shellcheck gate over scripts/*.sh would have caught nothing here, so the ask is executing pins for the other four
- 2026-09-13T21:01:57Z owner=1-18-epic-1-burn-down by=burndown note=chartered into the Epic 1 burn-down story, risk-led rather than sort-led: first-install and silent-refusal defects, release-blocking licence distribution, then CI reliability and vacuous pins
- 2026-09-14T00:42:24Z status=resolved-by:1-18-epic-1-burn-down by=adjudication note=shell-scripts.test.mjs syntax-checks the shell scripts on the shells they declare, so a guard like 1.17's credential check cannot ship unparsed

### DW-230: node --test tools/ failed one unnamed test once and has not reproduced in seven attempts
- source: lead-smoke-gate-1-17 | severity: med | fix-risk: high | footprint: in-epic
- evidence: Observed 2026-09-13 at the 1.17 smoke gate: one run reported tests=584 pass=583 fail=1 while two live smoke.sh invocations ran concurrently in a parallel tool call. The failing test's name was not captured - only the summary counts were. Seven subsequent runs are green: three isolated, one with a concurrent live smoke, three under eight-way CPU saturation. No shared fixed-name temp path exists (the credential test uses mkdtempSync; smoke.sh writes no temp file)
- 2026-09-13T16:35:06Z status=routed owner=burndown by=lead note=decision: record and watch rather than chase further. CI runs this suite, so a flake here erodes a gate. reopen_if=a second sighting, or any red run of node --test tools/ whose failing test name IS captured - run with --test-reporter=spec and keep the output
- 2026-09-13T19:31:26Z occurrence=1-17-the-smoke-script-the-readiness-endpoint-and-ci
- 2026-09-13T19:31:26Z status=routed owner=burndown by=harvest note=reopen_if FIRED during rework 2: the flake reproduced with its failing site captured - the connectivity probe's abort-timeout test. No longer an unnamed one-off. The gates matrix now runs the suite three times per push, so the exposure triples and the next sighting should be quick
- 2026-09-13T21:01:57Z owner=1-18-epic-1-burn-down by=burndown note=chartered into the Epic 1 burn-down story, risk-led rather than sort-led: first-install and silent-refusal defects, release-blocking licence distribution, then CI reliability and vacuous pins
- 2026-09-14T00:42:24Z status=resolved-by:1-18-epic-1-burn-down by=adjudication note=the connectivity abort-timeout test runs on mock timers instead of wall-clock; 50 of 50 runs green under eight busy CPU loops

### DW-231: node --test tools/ cannot run on Node 22, the version CI pins and the floor the project declares supported
- source: ci-run-34773637146 | severity: high | fix-risk: low | footprint: in-story
- evidence: CI gates job, Node v22.22.3: 'Error: Cannot find module /home/runner/work/OcuPilot/OcuPilot/ui/tools' MODULE_NOT_FOUND, fail 1. Directory scanning for --test arrived after Node 22, so the same command that scans tools/ on the local Node 26.8.1 tries to LOAD it as a module on 22. version-guard declares ^22.22.3 supported and ci.yml pins 22.22.3, so the declared floor cannot run the project's own test command. node --test tools/*.test.mjs gives 584/584 locally and is portable
- 2026-09-13T18:10:43Z status=routed owner=1-17-the-smoke-script-the-readiness-endpoint-and-ci by=cr note=CI failure on the story that created the workflow; HIGH per the CI gate, never deferrable
- 2026-09-13T21:00:46Z status=resolved-by:1-17-the-smoke-script-the-readiness-endpoint-and-ci by=burndown note=missed gate - rework 2 (98e1cb3) named the test files and made gates a matrix over each declared Node band floor; CI run 34778003004 gates on node 22.22.3 concluded success. Left owned by 1.17 because its iteration-2 review was skipped

### DW-232: The CI throwaway container reports unhealthy five seconds after start and nothing captures why
- source: ci-run-34773637146 | severity: high | fix-risk: med | footprint: in-story
- evidence: CI instance job: container started 18:09:02.3, 'container ocupilot-ci is unhealthy' 18:09:07.3, exit 1. Five seconds is before the first health check could run - interval is 10s and start_period 60s - so the container was not running rather than failing a probe. Undiagnosable from the log because the job has no failure-path step capturing docker compose logs or ps -a; the teardown runs if:always() and removes the evidence
- 2026-09-13T18:10:43Z status=routed owner=1-17-the-smoke-script-the-readiness-endpoint-and-ci by=cr note=CI failure on the story that created the workflow; the missing diagnostic is what makes it undiagnosable, so both halves are one item
- 2026-09-13T21:00:46Z status=resolved-by:1-17-the-smoke-script-the-readiness-endpoint-and-ci by=burndown note=missed gate - rework 2 (98e1cb3) chmod 777 on the durable directory, root-container scrub on teardown, failure()||cancelled() capture before teardown; CI run 34778003004 instance job concluded success. Cause confirmed on the runner as ERROR 5001 Cannot create target /durable/iris

### DW-233: Generate the demo X.509 pair at install instead of shipping a checked-in one
- source: epic-1-decision-sheet | severity: low | fix-risk: high | footprint: out-of-footprint
- evidence: Owner decision 2026-09-13: Release 1 keeps the checked-in CN=OcuPilotDemo prop (DW-49, DW-59 accepted), and generating at install becomes its own later story. PKI.CAServer.Configure generates a CA cert and key to files and %ZHSLIB.TLS.Utils uses it, so a supported path likely exists; the open question is AD-21, since %SYS.X509Credentials.LoadCertificate reads a filesystem path. Loading through it is also what populates SubjectDN, IssuerDN, Thumbprint, SerialNumber, validity and HasPrivateKey, so this closes DW-59's half too
- 2026-09-13T18:48:17Z status=decision-pending owner=burndown by=merge_gate note=needs a story key in a later epic; the lead creates it in epics.md at the burn-down gate and re-owns this entry to it
- 2026-09-13T21:00:47Z status=routed owner=6-3-the-x-509-ldap-kerberos-and-wallet-lists by=merge_gate note=owner decision 2026-09-13: add a story for generate-at-install later. 6-3 is that story - it displays the credential, and generating through LoadCertificate also fills the metadata DW-59 accepted as empty. AD-21 path constraint is the open question

### DW-234: docker-compose.yml's own iris-data mount carries the Linux ownership defect the throwaway just fixed, and nothing pins it
- source: spec-1-17-the-smoke-script-the-readiness-endpoint-and-ci.md | severity: med | fix-risk: med | footprint: out-of-footprint
- evidence: Rework 2 fixed ci-throwaway.sh: IRIS runs as uid 51773 and a bind-mounted host directory keeps host ownership on Linux, so a 0755 directory owned by the invoking user is one IRIS cannot write (ERROR #5001: Cannot create target: /durable/iris/, observed on runner 34773637146). The repository's own docker-compose.yml mounts ./iris-data:/durable the same way with no equivalent handling, so a first docker compose up on any Linux host hits the same failure. Invisible here because Docker Desktop maps bind-mount ownership to the calling user
- 2026-09-13T19:31:26Z status=routed owner=burndown by=harvest note=the project's documented quickstart is docker compose up -d --wait; this makes it fail on Linux
- 2026-09-13T21:01:57Z owner=1-18-epic-1-burn-down by=burndown note=chartered into the Epic 1 burn-down story, risk-led rather than sort-led: first-install and silent-refusal defects, release-blocking licence distribution, then CI reliability and vacuous pins
- 2026-09-14T00:42:24Z status=resolved-by:1-18-epic-1-burn-down by=adjudication note=a one-shot durable-init Compose service makes the bind-mounted /durable writable by uid 51773 before iris starts; scripts/ci-durable-ownership.sh reproduces the Linux defect in a named volume and fails first as a negative control. CI instance job on Linux is the end-to-end proof

### DW-235: ci-throwaway.sh's scratch-root guard admits any absolute path when TMPDIR is / and the directory it guards is now removed by a root container
- source: spec-1-17-the-smoke-script-the-readiness-endpoint-and-ci.md | severity: med | fix-risk: low | footprint: in-story
- evidence: The guard confines --dir under the scratch root; with TMPDIR=/ the root is / and any absolute path passes. Rework 2 added scrub_data, which falls back to docker run --user 0:0 rm -rf over the directory, so a guard that admits the wrong path now deletes with root privileges inside a container rather than failing on permissions
- 2026-09-13T19:31:26Z status=routed owner=burndown by=harvest note=harvested at dev_complete; the guard predates this pass but the root-container removal raises what a miss costs
- 2026-09-13T21:00:47Z status=routed owner=17-2-a-readme-whose-install-steps-work-the-first-time by=burndown note=ci-throwaway.sh scratch-root guard admits any absolute path when TMPDIR=/ and now deletes through a root container. 17-2 is the clean-clone reproducibility story that drives the throwaway

### DW-236: A widened SQL grant on OcuPilot_Kernel_State - another role or _PUBLIC holding it - is neither detected nor refused
- source: spec-1-18-epic-1-burn-down.md | severity: med | fix-risk: med | footprint: out-of-footprint
- evidence: The widened half of DW-96. The owner's design scoped 1.18 to the unreadable state, read-back of the escalation role's grant and a derived schema name; a grant widened to _PUBLIC or another role silently exposes OcuPilot's protected state and no gate sees it (Installer.cls EnsureSqlPrivileges)
- 2026-09-13T23:43:36Z status=routed owner=18-9-sql-privileges-and-the-permission-extras by=harvest note=18-9 owns SQL privileges; detection needs an enumeration of every grantee on the schema, not a single CheckPrivilege

### DW-237: The client keeps INSTALL.FAILED and INSTALL.UPGRADEREQUIRED in the install backoff forever, though neither clears by waiting
- source: spec-1-18-epic-1-burn-down.md | severity: med | fix-risk: low | footprint: in-story
- evidence: session.ts isInstallInFlight counts every INSTALL.* code except INSTALL.UNREADABLE, so a failed install shows Signing in and re-probes indefinitely while wait-readiness.sh already exits 1 on both. Pre-existing since 1.13, but 1.18 just built the terminal-notice path these two states belong on
- 2026-09-13T23:43:36Z status=open owner=1-18-epic-1-burn-down by=harvest note=in-story: the same file and the same pattern 1.18 built for unreadable; the review can patch it
- 2026-09-14T00:38:52Z status=wontfix-accepted by=cr note=premise false on the shipped path: a container FAILED clears through on-failure:3 or stops (unreachable), UPGRADEREQUIRED clears when the start hook installs, so backoff is right; permanent FAILED is IPM-only (AD-18) and a terminal notice would strand a restart that recovers. reopen_if=a FAILED or UPGRADEREQUIRED 503 persists on a container-path instance that keeps serving

### DW-238: The SHA-pinned actions/checkout v4, setup-node v4 and setup-uv v5 declare the node20 runtime GitHub has deprecated
- source: spec-1-18-epic-1-burn-down.md | severity: med | fix-risk: low | footprint: in-story
- evidence: A reviewer read using: node20 from each action. Run 34778003004 already logged GitHub forcing them onto Node 24 with a deprecation warning, so CI passes today; if GitHub removes the fallback, every job fails at checkout. Moving to node24 releases, re-pinned by SHA, closes it
- 2026-09-13T23:43:36Z status=open owner=1-18-epic-1-burn-down by=harvest note=in-story: 1.18 introduced the SHA pins in ci.yml
- 2026-09-14T00:38:52Z status=resolved-by:1-18-epic-1-burn-down by=cr note=re-pinned to the lowest node24 majors, SHAs and using: node24 read via gh api: checkout v5 fbc6f399, setup-node v5 a0853c24, setup-uv v7 37802adc; ci.test.mjs PINNED_ACTIONS moved with them; the first runner proof is the next CI run

### DW-239: Readiness answered HTTP 500 during a throwaway docker restart recompile, outside the envelope
- source: spec-1-18-epic-1-burn-down.md | severity: low | fix-risk: med | footprint: in-epic
- evidence: Recorded by the 1.18 implement stage in spec frontmatter (never harvested): two 500s while the start hook recompiled; likely a class mid-compile at dispatch (inference). Polls then read installed; never unreadable.
- 2026-09-14T00:38:52Z status=wontfix-accepted owner=1-18-epic-1-burn-down by=cr note=transient inside AD-38's accepted recompile window; wait-readiness keeps polling a 500. reopen_if=a 500 from readiness or the API outside a start's recompile, or a CI wait-readiness or smoke step failing on one

### DW-240: About 120 EXPERIENCE.md :n citations in ui/ comments point at lines that shifted when Fixed-strings rows were added
- source: spec-1-18-epic-1-burn-down.md | severity: low | fix-risk: low | footprint: in-epic
- evidence: Recorded by the 1.18 implement stage in spec frontmatter (never harvested). strings.test.mjs validates :n only in strings.ts; instance-notice.ts cited :428-429 (now Form login rows) until this review corrected it.
- 2026-09-14T00:38:52Z status=wontfix-accepted owner=1-18-epic-1-burn-down by=cr note=cosmetic, and every insertion shifts them again. reopen_if=a finding or defect traced to a stale EXPERIENCE.md :n citation in a ui/ comment

### DW-241: The spine's Stack table header dates every row 2026-09-09, though 8814be5 added the CI, CI tool pins and Docker Compose rows on 2026-09-13
- source: spec-1-18-epic-1-burn-down.md | severity: low | fix-risk: low | footprint: in-epic
- evidence: Lead edit 8814be5 added rows under 'Verified against the live instance and the web on 2026-09-09'. The values match cce429c plus this review's DW-238 re-pin (SHAs via gh api; uv, Python, markdownlint, puppeteer checked by two review layers).
- 2026-09-14T00:38:52Z status=wontfix-accepted owner=1-18-epic-1-burn-down by=cr note=lead-owned spine; values verified, only the date label is off. reopen_if=a Stack row under that header is found not to match the instance or repository

### DW-242: A test class leaks the probe profile's readiness application, so GrantReadBack's precondition fails when it runs after the classes before it
- source: ci-run-34793616419 | severity: high | fix-risk: low | footprint: in-story
- evidence: CI instance job: 41 classes, 364 tests, 1 failed - GrantReadBack.TestAGrantThatDidNotTakeFailsTheInstall, 'precondition: no probe web application exists before the install'. Reproduced deterministically on a throwaway by running CI's first 16 classes in order: /api/probeocupilot/readiness is left behind. The class passes 3/3 alone. The leaking cleanup removes probe applications by literal name and misses the third roster application - DW-192's pattern in test code
- 2026-09-14T00:54:19Z status=routed owner=1-18-epic-1-burn-down by=cr note=CI failure on the story just committed; HIGH per the CI gate
- 2026-09-14T02:22:42Z status=routed owner=1-18-epic-1-burn-down by=cr note=cause per replay: Escalation left the probe installed; GatewayGapIpmPath's teardown deleted the readiness row
- 2026-09-14T02:28:25Z status=resolved-by:1-18-epic-1-burn-down by=adjudication note=cause confirmed on a throwaway as two classes - Escalation leaving the probe profile installed and GatewayGapIpmPath's teardown deleting the readiness application's provenance row. ProbeApps derives probe applications and roles from the roster; ci-unit-test.sh and ci-runner.mjs fail a class that leaks one (LEAKED), name one inherited (INHERITED) and refuse to count an unreadable answer (UNCHECKED). Full suite on a throwaway 41 classes, 365 tests, 0 failed, 0 leftovers
- 2026-09-14T02:28:48Z by=adjudication note=correction to the trailer above: LEAKED and INHERITED are not literal output labels. The mechanism is ci-runner.mjs classifyLeftovers(), which splits a class's leftover probe applications into inherited (present before the class ran) and added, and fails the run on either in prose; UNCHECKED is the one literal label

### DW-243: ci-runner names a failing class but never the failing method or assertion message, so a red CI run states no cause
- source: ci-run-34793616419 | severity: med | fix-risk: low | footprint: in-story
- evidence: Run 34793616419 printed only 'GrantReadBack: 1 of 3 test(s) failed'. Finding the method and message took a local throwaway replaying the class order and a walk of ^UnitTest.Result - the same shape as the capture step 1.17 had to add for the container
- 2026-09-14T00:54:19Z status=routed owner=1-18-epic-1-burn-down by=cr note=a gate that fails without naming why costs a throwaway run every time
- 2026-09-14T02:28:25Z status=resolved-by:1-18-epic-1-burn-down by=adjudication note=ci-runner.mjs prints every failed method with each failed assertion's description and location, read by the run's own index, and fails a run whose detail is missing or disagrees with its failure count; a real failing throwaway run printed method, message and location

### DW-244: The probe role ProbeOcuPilotShell was seen present after Uninstall('probe') on an already-dirty throwaway
- source: spec-1-18-epic-1-burn-down.md | severity: low | fix-risk: low | footprint: in-epic
- evidence: Observed once by 1.18 rework 1's implementation pass on a throwaway that already carried leftovers, so the cause may be the dirty state rather than Uninstall; not reproduced on a clean throwaway. If real, Uninstall leaves a roster-declared role behind, the sibling of the application leak DW-242 fixed
- 2026-09-14T01:55:45Z status=wontfix-accepted owner=1-18-epic-1-burn-down by=harvest note=reopen_if=the ci-runner's before/after probe check reports a leftover role on a clean run, or any clean-throwaway Uninstall('probe') leaves ProbeOcuPilotShell
- 2026-09-14T02:22:42Z status=wontfix-accepted owner=1-18-epic-1-burn-down by=cr note=reopen_if=a clean-throwaway Uninstall('probe') leaves any Probe* role (the runner's check reads applications only)

### DW-245: Secondary and text buttons are content-box with a 1px border outside --ocu-control-height, so they stand 34px beside the primary's 32px
- source: spec-2-0-epic-1-deferred-cleanup.md | severity: low | fix-risk: low | footprint: in-story
- evidence: _components.scss:250 .ocu-button-secondary/.ocu-button-text height with no box-sizing and a 1px border; the classic-link card compensates with calc(+2px)
- 2026-09-14T03:54:44Z status=open owner=2-0-epic-1-deferred-cleanup by=harvest note=pre-existing; in the file this story edited
- 2026-09-14T04:29:06Z occurrence=2-0-epic-1-deferred-cleanup
- 2026-09-14T04:31:22Z status=wontfix-accepted by=adjudication note=reopen_if=a screen renders a primary button beside a secondary or text button and the browser measures different heights; the fix touches every secondary and text button plus two compensating workarounds and their pins

### DW-246: A ScreenActions handler registered from a routed page's lifecycle may notify during change detection (NG0100) or outlive its page if it does not unregister on destroy
- source: spec-2-0-epic-1-deferred-cleanup.md | severity: med | fix-risk: low | footprint: in-epic
- evidence: ui/src/app/core/screen-actions.ts: only component specs register; settled by a spec that registers in a routed page, unregisters via DestroyRef, navigates away and back, and asserts no NG0100 and one run per click (inference)
- 2026-09-14T03:54:44Z status=routed owner=8-1-create-a-web-application by=harvest note=Story 8.1 registers the first real handler

### DW-247: After an in-app sign-in or instance recovery swaps the frame in, the first Tab may not land on Skip to content
- source: spec-2-0-epic-1-deferred-cleanup.md | severity: med | fix-risk: low | footprint: in-story
- evidence: ui/src/app/app.ts: browser spec covers a fresh page load only; settled by a shell.browser-spec case that signs in through the form, presses Tab and asserts the skip link holds focus (inference)
- 2026-09-14T03:54:44Z status=open owner=2-0-epic-1-deferred-cleanup by=harvest note=unverified; in-story
- 2026-09-14T04:29:06Z occurrence=2-0-epic-1-deferred-cleanup
- 2026-09-14T04:31:22Z status=dropped by=adjudication note=sign-in path pinned by the shell.browser-spec in-app sign-in case and did not reproduce; the recovery and Enter-submit paths share DW-248's root cause (focus after the frame replaces the focused instance notice), decided there

### DW-248: When the frame replaces the focused instance notice after sign-in or instance recovery, focus falls to the document with no named destination
- source: spec-2-0-epic-1-deferred-cleanup.md | severity: med | fix-risk: low | footprint: in-story
- evidence: instance-notice.ts:129 focuses the notice on every non-ready render; app.ts:110-137 swaps it for the frame on ready and nothing moves focus; EXPERIENCE.md:596 requires a named destination
- 2026-09-14T04:29:06Z status=decision-pending owner=burndown by=cr note=destination unpublished: main#ocu-content, the screen heading (EXPERIENCE.md:595), or document start
- 2026-09-14T04:31:42Z status=routed owner=burndown by=merge_gate note=owner-delegated decision 2026-09-14: the frame's arrival after sign-in or recovery is treated as a route arrival per EXPERIENCE.md:595 - focus moves to the current screen's heading, else main#ocu-content; pin with a browser case for both paths
- 2026-09-15T08:26:31Z owner=2-13-epic-2-burn-down by=burndown note=chartered into the Epic 2 burn-down story
- 2026-09-15T08:38:21Z note=destination correction 2026-09-15 (spec_gate, measured): no route-arrival focus mechanism and no screen heading exist in the client (the screen title is a span in the locator bar), so the destination is the decision's fallback main#ocu-content; the skip-link assertions in shell.browser-spec.mjs (DW-247's pins) must be restated, not absorbed
- 2026-09-15T11:46:00Z status=resolved-by:2-13-epic-2-burn-down by=adjudication note=arrival focus lands in main#ocu-content after the frame replaces the instance notice; the skip link's first-Tab claim is restated in shell.browser-spec rather than absorbed

### DW-249: A caller holding %Admin_Secure but not %Admin_Operate can queue an audit record LIST task through AdminPort.Invoke, have its AsyncResult poll refused 403, and leave the queued task row behind
- source: spec-2-1-the-adminport-reproduces-the-vendor-s-dispatcher-exactly-onc.md | severity: med | fix-risk: low | footprint: in-epic
- evidence: Audit.Record ResourcesOR() is %Admin_Secure alone, AsyncResult ResourcesOR() is %Admin_Operate alone; AwaitTask returns the poll fault without ForgetTask (inference: no principal with that split was run)
- 2026-09-14T06:05:56Z status=routed owner=2-10-the-audit-database-viewer-with-its-agent-marker-filter by=harvest note=2.10 writes the audit screen's privilege set and can require both, or the port forgets the task on a refused poll
- 2026-09-15T03:43:23Z status=resolved-by:2-10-the-audit-database-viewer-with-its-agent-marker-filter by=adjudication note=the descriptor declares %Admin_Secure:USE, %Admin_Operate:USE and %DB_IRISSYS:READ, so the poll's own gate refuses before the LIST is queued and no task row can be orphaned; WireSecurityRead witnesses both sides and the matrix row is corrected to Refused before the queue

### DW-250: AdminPort.Invoke fails 500 INTERNAL when its caller is already inside a %SYS.Capture with buffered output, because BeginCaptureOutput refuses a nested capture
- source: spec-2-1-the-adminport-reproduces-the-vendor-s-dispatcher-exactly-onc.md | severity: med | fix-risk: low | footprint: out-of-footprint
- evidence: %SYS.Capture BeginCapture returns Capture Already Active whenever ^||%capture exists; Sequence stops on that status (inference: no consumer invokes the port under a capture yet)
- 2026-09-14T06:05:56Z status=routed owner=4-1-the-turn-runs-in-a-background-job-and-returns-immediately by=harvest note=real only if the turn job or tool executor captures output around a tool call

### DW-251: AdminPort.ImplementsRead trusts any endpoint that overrides Run, so a GET or LIST such a class leaves to the base (License.Key LIST, Monitor GET) still answers 200 {}
- source: spec-2-1-the-adminport-reproduces-the-vendor-s-dispatcher-exactly-onc.md | severity: low | fix-risk: med | footprint: in-story
- evidence: Live %Dictionary.CompiledMethod: 14 endpoint classes override Run with RunGet or RunList inherited; License.Key and WebAuth Run delegate unknown types to ##super, Monitor's own $CASE defaults to {} (inference: no descriptor names such a pair yet)
- 2026-09-14T06:42:03Z status=wontfix-accepted owner=2-1-the-adminport-reproduces-the-vendor-s-dispatcher-exactly-onc by=cr note=reopen_if=a descriptor names an endpoint and type Dispatch.v1 never constructs and Invoke returns 200 {}

### DW-252: AdminPort.Sequence calls OcuPilot seams (HoldsResource, OnBeforeRun, fixture endpoint methods) while in %SYS, where no OcuPilot package is mapped
- source: spec-2-1-the-adminport-reproduces-the-vendor-s-dispatcher-exactly-onc.md | severity: med | fix-risk: low | footprint: in-story
- evidence: Config.MapPackages maps OcuPilot in HSCUSTOM only; the calls resolve because each class is already loaded in the process before the switch (inference: no call in %SYS reaches a class not yet loaded)
- 2026-09-14T06:42:03Z status=wontfix-theoretical owner=2-1-the-adminport-reproduces-the-vendor-s-dispatcher-exactly-onc by=cr note=real if a call made in %SYS reaches an OcuPilot class the process has not loaded

### DW-253: LanguageServer's template is evaluated at its default type, so its Custom object derives member-less and no per-type field (ClassPath, JavaHome, PythonPath, Address) can enter a tool schema
- source: spec-2-2-write-tool-field-lists-are-derived-at-build-time-and-pinned.md | severity: med | fix-risk: med | footprint: out-of-footprint
- evidence: FieldLists.cls LanguageServer Custom is an object with no members; the vendor template builds Custom per type argument; AD-3 fixes no-argument evaluation except SSLConfig
- 2026-09-14T08:16:26Z status=routed owner=16-10-external-language-servers by=harvest note=decided 2026-09-14 (owner-delegated): derive one list per language-server type as Wallet.Secret does, amending AD-3 in that story

### DW-254: The credential pattern missed string secrets (wallet Secret64, License.Key Key) and refuses ordinary on the string OAuth2 ReturnRefreshToken
- source: spec-2-2-write-tool-field-lists-are-derived-at-build-time-and-pinned.md | severity: med | fix-risk: low | footprint: in-story
- evidence: isCredential over the committed lists: Secret64 in all three wallet lists and License.Key Key unmatched; Security.OAuth2.Server ReturnRefreshToken matches
- 2026-09-14T08:16:26Z status=open owner=2-2-write-tool-field-lists-are-derived-at-build-time-and-pinned by=harvest note=spine Conventions Secrets amended 2026-09-14: add secret64 suffix and exact name Key; ReturnRefreshToken stays secret; patch CREDENTIAL_RE and its test in this story
- 2026-09-14T08:45:54Z status=resolved-by:2-2-write-tool-field-lists-are-derived-at-build-time-and-pinned owner=2-2-write-tool-field-lists-are-derived-at-build-time-and-pinned by=cr note=CREDENTIAL_RE adds secret64 and ^key$; per-ending and Secret64/Key/PrivateKey refusal tests; mutations observed red

### DW-255: The log backstop redactor (Log.IsCredentialName) does not match a key named exactly Key, which the amended Conventions Secrets pattern names
- source: spec-2-2-write-tool-field-lists-are-derived-at-build-time-and-pinned.md | severity: low | fix-risk: low | footprint: out-of-footprint
- evidence: CREDENTIALNAMES is a substring list that deliberately omits key; the 2026-09-14 Secrets row adds an exact-Key match; IsCredentialName("Key") is 0 by inspection of the list
- 2026-09-14T08:45:54Z status=wontfix-accepted owner=2-2-write-tool-field-lists-are-derived-at-build-time-and-pinned by=cr note=reopen_if=a logged or ledgered payload carries a member named Key (a License.Key write tool); schema-driven redaction is primary

### DW-256: A misspelt or unknown key in a descriptor's context or read (e.g. secretfields) passes both the instance and mirror refusals, so the read tool strips nothing
- source: spec-2-3-one-descriptor-declared-read-serves-both-the-screen-and-its.md | severity: med | fix-risk: low | footprint: in-story
- evidence: Registry ReadProblem and screen-mirror readProblem skip secret checks when context.secretFields is absent and refuse no unknown keys in read, read.source or context; Tool.Read.View strips only ContextSecretFields
- 2026-09-14T10:25:56Z status=open owner=2-3-one-descriptor-declared-read-serves-both-the-screen-and-its by=harvest note=fail closed: refuse unknown keys in both refusals
- 2026-09-14T11:04:08Z status=resolved-by:2-3-one-descriptor-declared-read-serves-both-the-screen-and-its by=adjudication note=Registry.ReadProblem and screen-mirror readProblem refuse unknown keys in read, read.source, read.sort and context, and a read requires context.secretFields; six refusal cases per engine

### DW-257: Spine Conventions REST route ordering row says each invariant is asserted by its own routing test; invariant 3 is observable only by check-objectscript.py
- source: spec-2-3-one-descriptor-declared-read-serves-both-the-screen-and-its.md | severity: low | fix-risk: low | footprint: in-story
- evidence: ARCHITECTURE-SPINE.md:532 still reads 'each asserted by its own routing test'; Story 2.3 showed a :param compiles to ([^/]+) so N-segment order cannot be observed by routing, and Router.cls now names check-objectscript.py
- 2026-09-14T11:01:58Z status=open owner=2-3-one-descriptor-declared-read-serves-both-the-screen-and-its by=cr note=lead: Rule 20 conv amend of the row (spine is lead-written); not patchable by cr
- 2026-09-14T11:04:08Z status=resolved-by:2-3-one-descriptor-declared-read-serves-both-the-screen-and-its by=adjudication note=spine Conventions REST route ordering row amended: all three invariants enforced by check-objectscript.py, the third not observable by routing

### DW-258: NFR-1 end to end - an instance read of a thousand rows through the screen route plus the table's first render within two seconds on a Community container - is unmeasured: Story 2.4 measures only the table over a harness read
- source: spec-2-4-the-data-table.md | severity: med | fix-risk: low | footprint: in-epic
- evidence: no stock list holds 1,000 rows on a fresh container (46 web applications live); the audit database does; Story 2.4 harness is real Chrome but not IRIS
- 2026-09-14T11:41:56Z status=routed owner=2-10-the-audit-database-viewer-with-its-agent-marker-filter by=spec_gate note=owner-delegated decision 2026-09-14: the audit viewer carries the end-to-end timing browser spec on the throwaway
- 2026-09-15T03:43:23Z status=resolved-by:2-10-the-audit-database-viewer-with-its-agent-marker-filter by=adjudication note=audit.browser-spec.mjs seeds a throwaway to a thousand audit rows, asserts aria-rowcount 1001 and the first data row in the DOM inside the budget from the Search press, with an assertion that the measurement is of a real read; 50/50 browser on the throwaway

### DW-259: A table column over a field context.secretFields names is not refused, and the screen read returns that field's value unmasked, against the Secrets convention's never returned
- source: spec-2-4-the-data-table.md | severity: med | fix-risk: low | footprint: in-story
- evidence: Registry.TableProblem and screen-mirror tableProblem do not check columns against context.secretFields; OcuPilot.Screen.Read returns every read field; Conventions Secrets: write-only, never returned; DESIGN.md renders a secret as a mask
- 2026-09-14T12:56:48Z status=open owner=2-4-the-data-table by=harvest note=decided 2026-09-14 (lead, owner-delegated): refuse a table column over a secret field in both engines, and strip context.secretFields from the screen route's rows so no secret leaves the instance
- 2026-09-14T13:49:49Z status=resolved-by:2-4-the-data-table by=adjudication note=both engines refuse a table column over context.secretFields; Screen.Read.Execute strips secret fields once for the route and the tool; ScreenRead.cls asserts neither name nor value reaches the response

### DW-260: No list offers the manual Refresh action EXPERIENCE.md requires on every list; the command bar renders only the auto-refresh chip, and the web applications list is the first live list
- source: spec-2-5-the-web-applications-list.md | severity: med | fix-risk: low | footprint: in-epic
- evidence: command-bar.ts renders only the chip gated on hasRefreshChip; no Fixed strings row names a Refresh action; no epics story carries it; RefreshService.readNow exists (2.4)
- 2026-09-14T15:17:36Z status=routed owner=burndown by=harvest note=in-epic file owned by 2.4 (cr_complete); a Refresh command-bar action calling readNow plus its Fixed strings row
- 2026-09-15T02:56:12Z occurrence=2-10-the-audit-database-viewer-with-its-agent-marker-filter note=the audit viewer needs a manual Refresh most: it never auto-refreshes, so a stale result can only be re-read by pressing Search again
- 2026-09-15T08:26:31Z owner=2-13-epic-2-burn-down by=burndown note=chartered into the Epic 2 burn-down story
- 2026-09-15T11:46:01Z status=resolved-by:2-13-epic-2-burn-down by=adjudication note=a manual Refresh action on every list page, silent (no skeleton) and preserving sort, filter, selection and scroll; browser leg on the task schedule and a silence assertion on the audit viewer

### DW-261: EXPERIENCE.md:N line citations in client comments drift one line early after every Fixed strings row insertion; about 137 are stale after Story 2.5 and only strings.ts is pinned
- source: spec-2-5-the-web-applications-list.md | severity: low | fix-risk: low | footprint: in-epic
- evidence: strings.test.mjs pins strings.ts citations only; other /** EXPERIENCE.md:n */ comments are unchecked
- 2026-09-14T15:17:36Z status=wontfix-accepted owner=2-5-the-web-applications-list by=harvest note=reopen_if=a review finding is traced to a stale EXPERIENCE.md:N citation outside strings.ts
- 2026-09-14T18:20:02Z occurrence=2-6-the-users-list
- 2026-09-14T19:09:40Z occurrence=2-7-the-ssl-tls-configurations-list
- 2026-09-14T20:00:36Z occurrence=2-7-the-ssl-tls-configurations-list note=five //-style EXPERIENCE.md citations in strings.ts resolve three lines high, pre-existing and unguarded by strings.test.mjs

### DW-262: WebAppList may under-declare its gate: it names only %Admin_Secure:USE while AdminPort switches to %SYS, whose database resource %DB_IRISSYS has no public permission, so a %Admin_Secure-only user would pass the gate and fail inside the port with no pair named (inference)
- source: spec-2-6-the-users-list.md | severity: med | fix-risk: low | footprint: in-epic
- evidence: WebAppList.cls declares one pair; AdminPort sets $NAMESPACE to %SYS; %DB_IRISSYS PublicPermission empty (probed 2026-09-14); Wire.cls shows a principal without %DB_IRISSYS refused %SYS
- 2026-09-14T16:13:41Z status=routed owner=2-6-the-users-list by=harvest note=2.6 proves the security read pair set with a real principal on the throwaway; if confirmed, add %DB_IRISSYS:READ to WebAppList and pin it with the same principal
- 2026-09-14T18:21:33Z status=resolved-by:2-6-the-users-list by=adjudication note=confirmed on the throwaway (%Admin_Secure-only principal got 500 from the port); WebAppList declares %Admin_Secure:USE + %DB_IRISSYS:READ; WireSecurityRead proves each pair necessary and both sufficient

### DW-263: The Permissions and Web applications areas require only %Admin_Secure:USE, so a holder of that alone sees both areas allowed in the rail and is refused on every screen inside, which now also need %DB_IRISSYS:READ
- source: spec-2-6-the-users-list.md | severity: med | fix-risk: low | footprint: in-epic
- evidence: Screen/Area.cls XData Areas pairs for web-applications and permissions name %Admin_Secure:USE only; WebAppList and UserList declare %Admin_Secure:USE + %DB_IRISSYS:READ (throwaway-proven)
- 2026-09-14T17:44:53Z status=open owner=2-6-the-users-list by=harvest note=patch in this story's review: add %DB_IRISSYS:READ to both areas' pairs and pin the rail verdict with the throwaway principal
- 2026-09-14T18:21:33Z status=resolved-by:2-6-the-users-list by=adjudication note=Area.cls web-applications and permissions declare %DB_IRISSYS:READ beside %Admin_Secure:USE; Navigation TestAnAreaGatesOnItsOwnDeclaredSet and WireSecurityRead area verdicts for three principals

### DW-264: Whether every admin-port read, not only Security.User and WebApp.App, needs %DB_IRISSYS:READ is unproven, and nothing in the read grammar requires a descriptor to declare it
- source: spec-2-6-the-users-list.md | severity: med | fix-risk: low | footprint: in-epic
- evidence: AdminPort switches to %SYS whose %DB_IRISSYS has no public permission; proven on the throwaway for Security.User LIST/GET and WebApp.App LIST only (inference for the rest)
- 2026-09-14T17:44:53Z status=routed owner=2-7-the-ssl-tls-configurations-list by=harvest note=each list story proves its pair set with a real principal on the throwaway; if every admin-port read needs it, make Registry.ReadProblem refuse an admin-port read without %DB_IRISSYS:READ
- 2026-09-14T20:24:50Z status=resolved-by:2-7-the-ssl-tls-configurations-list by=adjudication note=settled at the port mechanism, not by extrapolation: AdminPort.RunSequence switches to %SYS for every request type, so Registry.ReadProblem and screen-mirror readProblem refuse an admin-port read whose privileges omit %DB_IRISSYS:READ, one sentence pinned by AdminPairCorpus in both engines

### DW-265: The spine's Dates convention says never $Horolog while AD-36 has beforeToday compare against today on the instance clock, which Read.Derive reads as +$Horolog
- source: spec-2-6-the-users-list.md | severity: low | fix-risk: low | footprint: out-of-footprint
- evidence: Consistency Conventions Dates row vs AD-36 Rule; Read.cls Derive uses +$Horolog; the throwaway probe showed IRIS's own expiry check agrees with the local date, so $ZTimeStamp would disagree with sign-in
- 2026-09-14T18:20:02Z status=by-design owner=2-6-the-users-list by=cr note=the Dates row governs emitted ISO-8601 timestamps; AD-36 names the instance clock; lead may scope the row (Rule 20)
- 2026-09-14T18:21:33Z note=lead amended the spine Conventions Dates row 2026-09-14: UTC rule scoped to emitted timestamps, instance calendar comparisons use +$Horolog

### DW-266: Nothing checks that an area's declared privilege pair set covers the union of its screens' sets, so a later screen needing a pair its area does not name leaves the area allowed and every screen inside refused - the DW-263 defect, undetected
- source: spec-2-6-the-users-list.md | severity: med | fix-risk: low | footprint: in-epic
- evidence: Area.cls and each descriptor declare pairs as independent literals; Registry.Validate checks area keys, not pair coverage; Descriptor's vocabulary test pins all eight areas by content but against a hand-written expectation, not against the screens
- 2026-09-14T18:47:22Z status=routed owner=2-7-the-ssl-tls-configurations-list by=harvest note=same family as DW-264: prove and then enforce pair sets; Registry.Validate should refuse a screen whose pair set its area does not cover
- 2026-09-14T18:56:33Z status=routed owner=2-7-the-ssl-tls-configurations-list by=cr note=scope correction: Gate.RequiredPairs never unions the area set, so only screens declaring the missing pair are refused, not every screen inside
- 2026-09-14T20:24:50Z status=resolved-by:2-7-the-ssl-tls-configurations-list by=adjudication note=Registry.AreaCoverageProblem refuses a screen declaring a pair its area does not cover, called from Validate after MalformedPair and named in the refusal; Test/AreaPair/Bad.cls is the falsifying fixture and the security area gained %DB_IRISSYS:READ

### DW-267: The browser specs' filter step is vacuous in users.browser-spec.mjs and web-applications.browser-spec.mjs: the helper is triplicated rather than shared, and the copies assert a filter that matches every row
- source: spec-2-7-the-ssl-tls-configurations-list.md | severity: med | fix-risk: low | footprint: in-epic
- evidence: Story 2.7 found and fixed the same vacuity in its own copy; web-applications declares five filter fields and its step passes whatever the filter does
- 2026-09-14T20:00:36Z status=routed owner=2-8-the-task-schedule-list by=harvest note=share one filter helper across the list browser specs when 2.8 adds the next one, and make each copy fail when the filter matches nothing
- 2026-09-14T22:37:14Z status=resolved-by:2-8-the-task-schedule-list by=adjudication note=one shared ui/browser/list-spec.mjs filterToSubset reads aria-rowcount and asserts 0 < kept < total; all four list browser specs use it, so a filter matching everything or nothing now reddens

### DW-268: CREDENTIAL_RE is suffix-anchored, so the repo-wide build guard matches only one of the six key-material names an SSL configuration GET can carry
- source: spec-2-7-the-ssl-tls-configurations-list.md | severity: low | fix-risk: low | footprint: in-epic
- evidence: field-lists.mjs CREDENTIAL_RE anchors at the end of a name; widening it re-classifies across 47 generated field lists
- 2026-09-14T20:00:36Z status=wontfix-accepted owner=2-7-the-ssl-tls-configurations-list by=harvest note=reopen_if=a descriptor or tool schema emits a key-material field the guard did not catch
- 2026-09-14T20:24:50Z status=routed owner=9-5-the-ssl-tls-editor by=adjudication note=reopened on the reviewer's evidence: the SSL/TLS editor's detail read carries PrivateKeyFile, PrivateKeyType, CertificateFile, CAFile and CAPath, five of the six names the suffix-anchored guard misses, so the hole is reachable there; widen CREDENTIAL_RE (or add an exact-name set) and re-check field-lists classification in that story

### DW-269: The vendor tasks LIST coerces every task's Suspended to false, so a suspended task cannot be told from a running one in a list read - Story 4.10's Home line 'tasks suspended after an error' has no source
- source: spec-2-8-the-task-schedule-list.md | severity: med | fix-risk: low | footprint: in-epic
- evidence: Task.CRUD LIST reports Suspended false for ids 4 and 21 while SQL over %SYS.Task shows Suspended=2 and Task.CRUD INFO on id 4 answers true; the vendor coerces a three-value display column to Yes/No
- 2026-09-14T20:35:24Z status=routed owner=4-10-home-s-suggested-view-and-the-starter-prompts by=spec_gate note=AD-36 amended 2026-09-14 so a rowGet may declare its detail type: declare INFO for the task list's Suspended when the Home line needs it
- 2026-09-14T22:35:47Z occurrence=2-8-the-task-schedule-list
- 2026-09-14T22:35:47Z status=routed owner=4-10-home-s-suggested-view-and-the-starter-prompts by=cr note=epics.md:2019 Story 2.8 AC3 still promises a suspended task appears; AC2 was amended at origin, AC3 was not

### DW-270: A stopped Task Manager raises no banner: the strip matches only Status Suspended, so an instance whose scheduler is not running renders the full schedule silently - the very consequence the banner exists to announce
- source: spec-2-8-the-task-schedule-list.md | severity: med | fix-risk: low | footprint: in-epic
- evidence: Read.BannerKey matches Status='Suspended' only; Task.Manager GET answers Running, Suspended or a stopped state; EXPERIENCE.md publishes one sentence and no row for the stopped case
- 2026-09-14T22:06:25Z status=routed owner=burndown by=harvest note=owner-delegated decision 2026-09-14: the stopped case gets its own sentence and Fixed strings row, added by the story that implements it (a row with no key breaks strings.test.mjs's count, so do both together)
- 2026-09-15T08:26:31Z owner=2-13-epic-2-burn-down by=burndown note=chartered into the Epic 2 burn-down story
- 2026-09-15T11:46:01Z status=resolved-by:2-13-epic-2-burn-down by=adjudication note=the banner declaration takes multiple cases, so a stopped Task Manager raises its own sentence; a fixture source resolves the stopped value and its Fixed strings row shipped in the same pass

### DW-271: A screen descriptor's top-level keys are not a closed set, so a misspelled optional key installs silently -- 'banners' or 'Banner' validates, mirrors and ships a screen that never raises its strip
- source: spec-2-8-the-task-schedule-list.md | severity: med | fix-risk: med | footprint: out-of-footprint
- evidence: Registry.Validate applies UnknownKeyProblem to read, read.source, read.sort, context, rowGet, table, table.columns and now banner/banner.source (Registry.cls:367,375,460,468,500,521,602,625,689,704; mirrored in screen-mirror.mjs) but never to the declaration object itself; banner is the first top-level key whose absence is legal, so a typo is undetectable by either engine
- 2026-09-14T22:35:43Z status=routed owner=burndown by=cr note=Same silent-invisible-strip class the story closed one level down for banner.messageKey. Fix is a top-level closed key set in both engines plus a corpus case; no epic-2 story owns the grammar
- 2026-09-15T08:26:31Z owner=2-13-epic-2-burn-down by=burndown note=chartered into the Epic 2 burn-down story
- 2026-09-15T11:46:01Z status=resolved-by:2-13-epic-2-burn-down by=adjudication note=Registry.DeclarationProblem closes the descriptor's top-level key set in both engines, pinned instance-side through Validate and client-side through the mirror

### DW-272: 148 EXPERIENCE.md line citations outside strings.ts are behind no gate, and this story's Fixed-strings row insertion made six of them resolve to a wrong but plausible row rather than dangling
- source: spec-2-8-the-task-schedule-list.md | severity: med | fix-risk: med | footprint: out-of-footprint
- evidence: strings.test.mjs re-resolves the /** EXPERIENCE.md:n */ comments in strings.ts alone; grep over ui/src/**/*.ts finds 148 further citations, :318 six times -- command-bar.ts:51 and :70 cite :318 for 'a readout, not a control', a sentence now at :336, while :318 is the row this story inserted
- 2026-09-14T22:35:45Z status=routed owner=burndown by=cr note=The story repaired the ten in strings.ts as specified; the gap is repo-wide. Fix is to widen the existing resolver to every ui/src citation, or to drop line numbers from prose citations
- 2026-09-15T00:27:39Z occurrence=2-9-the-processes-list note=this story hand-corrected several EXPERIENCE.md internal citations after a two-row insertion and introduced one wrong bump (a prd.md citation) that review caught; the burn-down's fix should re-resolve citations mechanically
- 2026-09-15T00:43:35Z occurrence=2-9-the-processes-list note=cr measured the blast radius: 101 citations above :318 now resolve to a different line, and screen-store.ts:129 (':580' for 'refresh is silent') was correct before this story and wrong after -- patched in review; the other ~90 were already stale
- 2026-09-15T02:56:12Z occurrence=2-10-the-audit-database-viewer-with-its-agent-marker-filter note=this story moved twelve EXPERIENCE self-citations by four by hand and declined a blanket re-resolution because about sixty source citations did not resolve before it either
- 2026-09-15T08:23:44Z occurrence=2-12-the-application-error-log-endpoint-and-drill-down
- 2026-09-15T08:26:32Z owner=2-13-epic-2-burn-down by=burndown note=chartered into the Epic 2 burn-down story
- 2026-09-15T08:38:21Z note=measurement correction 2026-09-15 (spec_gate): 120 citations in ui/src, not 148, and 111 are already stale; a line-only check would still pass 101 of them, so the fix anchors each citation to a quoted phrase
- 2026-09-15T11:46:01Z status=resolved-by:2-13-epic-2-burn-down by=adjudication note=EXPERIENCE.md citations in ui/src are anchored to a quoted phrase and gated by ui/tools/citations.test.mjs; the gate's window was widened at review to catch six it first missed
- 2026-09-15T13:04:16Z occurrence=3-0-epic-2-deferred-cleanup note=EXPERIENCE.md's own :N self-citations are still gated by nothing, and inserting the Fixed strings row at :329 broke that document's :343 back-reference, which the review caught and fixed

### DW-273: A list screen's table frame collapses to its header's height in the shell, so the virtual-scroll viewport reads clientHeight 0, rows overflow the frame and the footer paints over them - a real pointer click at a row's centre reaches the footer, not the row
- source: spec-2-8-the-task-schedule-list.md | severity: med | fix-risk: med | footprint: in-epic
- evidence: measured in headless Chrome against ocupilot-ci on all four list routes: cdk-virtual-scroll-viewport clientHeight 0 with scrollHeight 1620/360/108/684; pre-existing in Story 2.4's ListPage/DataTable height chain (app-list-page height 100% over an outlet with no definite height)
- 2026-09-14T22:37:14Z status=routed owner=burndown by=harvest note=user-facing and reproduces on every list; the browser specs work around it by clicking above the fold, which is why no spec caught it
- 2026-09-15T08:26:31Z owner=2-13-epic-2-burn-down by=burndown note=chartered into the Epic 2 burn-down story
- 2026-09-15T11:46:01Z status=resolved-by:2-13-epic-2-burn-down by=adjudication note=app-screen-outlet gained the definite-height rule it never had; a browser leg measures the viewport and hits a row's centre with elementFromPoint

### DW-274: AdminPort answers 500 INTERNAL when the query behind an endpoint refuses on its own privilege check, so a privilege refusal arrives disguised as a server fault with no pair named
- source: spec-2-9-the-processes-list.md | severity: med | fix-risk: med | footprint: in-epic
- evidence: %SYS.ProcessQuery returns $$$OperationRequires when %Admin_Manage:USE is absent; %Api.Admin.Util.ClassQuery never checks what %Execute() returned, and Fault.Outcome maps the resulting status to 500 (probed 2026-09-14)
- 2026-09-14T23:44:35Z status=routed owner=burndown by=spec_gate note=owner-delegated decision 2026-09-14: map a vendor OperationRequires status to a named 403 PORT.ACCESSDENIED carrying the resource it names, so a screen that under-declares refuses honestly instead of faulting
- 2026-09-15T00:27:39Z note=correction 2026-09-14: the vendor OperationRequires status does not reach OcuPilot - %Api.Admin.Util.ClassQuery discards what %Execute() returned, so the port sees an empty result set, not an error. The burn-down's work is to make the port detect the refused query (probe the resource the query names, or read the result set's own status) and answer a named 403; it must also add the standing assertion this story could only demonstrate as a one-off mutation
- 2026-09-15T08:26:31Z owner=2-13-epic-2-burn-down by=burndown note=chartered into the Epic 2 burn-down story
- 2026-09-15T11:46:01Z status=resolved-by:2-13-epic-2-burn-down by=adjudication note=AdminPort declares each endpoint's backing-query pair requirement (QUERYPAIRS, any-of), probes it only on the error path and answers a named 403 carrying the failing pair; the vocabulary gained its own grammar, corpus and checker at review

### DW-275: Area coverage will gate the whole OS management area on %Admin_Manage:USE once Locks and Process details land, so an %Admin_Operate-only operator loses the rail item for screens that may not need that pair
- source: spec-2-9-the-processes-list.md | severity: med | fix-risk: low | footprint: in-epic
- evidence: AreaCoverageProblem requires an area to cover every screen's pairs; the processes list needed %Admin_Manage:USE, and Stories 6.8 and 7.8 add screens to the same area
- 2026-09-15T00:27:39Z status=routed owner=burndown by=harvest note=decide at the burn-down whether the area declares the union (a false denial for narrower screens) or coverage is relaxed to per-screen gating
- 2026-09-15T08:26:32Z owner=2-13-epic-2-burn-down by=burndown note=chartered into the Epic 2 burn-down story
- 2026-09-15T08:38:21Z note=already decided 2026-09-15 (spec_gate): DW-278's owner-delegated decision declined relaxing AreaCoverageProblem, so only declare-the-union remains - the work is to record and pin it; the charter's story numbers were off (Locks is 6.10; 7.8 is process actions) and the union does not grow when 6.8 and 6.10 land
- 2026-09-15T11:46:01Z status=resolved-by:2-13-epic-2-burn-down by=adjudication note=the os-management area declares the union and the false denial it implies is recorded and pinned

### DW-276: The command bar's sort control now renders on the four already-shipped lists, and no browser leg asserts it at their own surface
- source: spec-2-9-the-processes-list.md | severity: low | fix-risk: low | footprint: in-epic
- evidence: the control is shared surface added by Story 2.9; only processes.browser-spec.mjs drives it
- 2026-09-15T00:27:39Z status=wontfix-accepted owner=2-9-the-processes-list by=harvest note=reopen_if=a list screen ships with a sort control that does not order its rows, or the shared helper changes shape

### DW-277: The audit API's JSON payload search (its only text-shaped parameter) is not offered by the viewer: it matches inside an event's captured JSON and forces the event type to SQL, so it is a mode rather than a ninth criterion
- source: spec-2-10-the-audit-database-viewer-with-its-agent-marker-filter.md | severity: low | fix-risk: low | footprint: in-epic
- evidence: %SYS.Audit List takes thirteen parameters and none filters Description or free text; JSONSearch sets EventTypes to %SQL (Audit.cls:1765); the classic portal labels it JSON String Search beside a separate SQL Statement Type control
- 2026-09-15T00:56:31Z status=wontfix-accepted owner=2-10-the-audit-database-viewer-with-its-agent-marker-filter by=spec_gate note=owner-delegated decision 2026-09-14: Release 1 drops the criterion rather than shipping a control that silently discards the type filter; reopen_if=a user needs to search captured SQL audit payloads, and then ship it under its own name with the type control disabled while it is filled

### DW-278: Adding %Admin_Secure:USE to the Logs area gates the whole Logs rail entry on it, including Stories 2.11 and 2.12's screens, which need only %Admin_Operate
- source: spec-2-10-the-audit-database-viewer-with-its-agent-marker-filter.md | severity: med | fix-risk: low | footprint: in-epic
- evidence: AreaCoverageProblem requires the area to cover every screen's pairs; the audit viewer needs %Admin_Secure:USE while the messages.log and application error log reads do not
- 2026-09-15T02:56:12Z status=routed owner=2-11-the-messages-log-paging-endpoint by=harvest note=same family as DW-275: decide per-screen gating or accept the union's false denial when 2.11 lands in the same area
- 2026-09-15T03:57:18Z status=routed owner=6-14-the-messages-log-viewer by=spec_gate note=owner-delegated decision 2026-09-14: accept the union's false denial (relaxing AreaCoverageProblem would trade it for the false admission AD-8 names, and a ninth area contradicts the fixed vocabulary); Story 2.11 ships no Logs screen so nothing it delivers reaches the denial - the viewer story decides whether the screen declares the pair or the area splits

### DW-279: A criterion value longer than the vendor's own column for that parameter fails inside the queued task's save and answers 500, where the declared grammar has no length to refuse it by
- source: spec-2-10-the-audit-database-viewer-with-its-agent-marker-filter.md | severity: med | fix-risk: low | footprint: in-epic
- evidence: probed live: an 83-character pids value answers 500; read.criteria has no maxLength and the refusal happens after queueing
- 2026-09-15T02:56:12Z status=routed owner=burndown by=harvest note=add a maxLength to the criteria grammar, refused in both engines before the port is called - the same shape as the choice options check
- 2026-09-15T08:26:31Z owner=2-13-epic-2-burn-down by=burndown note=chartered into the Epic 2 burn-down story
- 2026-09-15T11:46:01Z status=resolved-by:2-13-epic-2-burn-down by=adjudication note=the criterion grammar carries maxLength, refused by name before the port, with the vendor MAXLEN pinned through AdminPort.EndpointClass rather than a literal

### DW-280: The audit criteria form tells the user to include a time but does not require one, so a bare date in the End field silently drops the whole of that day
- source: spec-2-10-the-audit-database-viewer-with-its-agent-marker-filter.md | severity: low | fix-risk: low | footprint: in-story
- evidence: endDateTime is passed through as typed; the vendor treats a bare date as midnight, so events later that day fall outside the range
- 2026-09-15T02:56:12Z status=open owner=2-10-the-audit-database-viewer-with-its-agent-marker-filter by=harvest note=either require the time or normalise a bare End date to the end of that day, and pin it
- 2026-09-15T03:41:39Z status=resolved-by:2-10-the-audit-database-viewer-with-its-agent-marker-filter by=cr note=Read.SeedCriteria now requires a datetime criterion to carry its time part, refused 400 READ.CRITERION before the port on both callers; Test.AuditRead pins it, mutation red alone

### DW-281: AD-24's field-level bound is unimplemented project-wide, so a read tool's payload carries an unbounded EventData blob for every row it returns
- source: spec-2-10-the-audit-database-viewer-with-its-agent-marker-filter.md | severity: med | fix-risk: med | footprint: out-of-footprint
- evidence: the audit read declares EventData and the tool view strips only secret fields; AD-24 specifies a per-field bound that no code applies
- 2026-09-15T02:56:12Z status=routed owner=4-4-screen-context-on-every-turn-capped-with-its-toggle-and-chip by=harvest note=the context cap story owns AD-24's bounds; a per-field truncation belongs with the row cap it already applies
- 2026-09-15T08:23:44Z occurrence=2-12-the-application-error-log-endpoint-and-drill-down

### DW-282: A criteria-bearing screen owns its state in a root-provided store because the detail route re-creates the component, and nothing stops the next such screen re-deriving that
- source: spec-2-10-the-audit-database-viewer-with-its-agent-marker-filter.md | severity: low | fix-risk: low | footprint: in-epic
- evidence: the audit page provides its store at the root; the pattern is undocumented and unenforced
- 2026-09-15T02:56:12Z status=wontfix-accepted owner=2-10-the-audit-database-viewer-with-its-agent-marker-filter by=harvest note=reopen_if=a second criteria screen keeps its state in the component and loses it on a detail-route round trip

### DW-283: The client's first role=dialog has no real-browser check that it is visible, sized and reachable by a real pointer: jsdom computes no layout and the AC3 leg opens and closes it with synthetic events
- source: spec-2-10-the-audit-database-viewer-with-its-agent-marker-filter.md | severity: low | fix-risk: low | footprint: in-story
- evidence: dialog.spec.ts is jsdom only; audit.browser-spec.mjs AC3 uses a synthetic MouseEvent, an in-page button.click() and page.keyboard, and asserts nothing about rect, viewport or elementFromPoint
- 2026-09-15T03:41:47Z status=wontfix-theoretical owner=2-10-the-audit-database-viewer-with-its-agent-marker-filter by=cr note=reviewed the z-index ladder: the scrim at 6 and the surface at 7 are the top two, nothing else exceeds 5, and the surface is fixed at 440px centred - real if a shell surface is declared at z-index 7 or above, or the fixed positioning is overridden

### DW-284: The audit detail dialog's route-driven lifecycle leaves two edges unhandled: a cold deep link to a row id before any Search shows the criteria form with no dialog and no explanation, and leaving the dialog with browser Back drops focus to the body
- source: spec-2-10-the-audit-database-viewer-with-its-agent-marker-filter.md | severity: low | fix-risk: low | footprint: in-story
- evidence: audit.page.ts's detail getter returns early unless search.searched(), so the id segment is inert on a cold arrival; requestGridFocus runs from onCloseDetail alone, not from the id-route teardown
- 2026-09-15T03:41:51Z status=wontfix-accepted owner=2-10-the-audit-database-viewer-with-its-agent-marker-filter by=cr note=both need a product call (redirect to the bare route, or open the dialog after an implied search); reopen_if=a user reports a pasted row link that shows no dialog, or keyboard focus lost after Back

### DW-285: The smoke script's audit area-list check issues a criteria-free vendor LIST, whose elapsed time tracks the whole matching audit population rather than its maxRows=1 cap
- source: spec-2-10-the-audit-database-viewer-with-its-agent-marker-filter.md | severity: low | fix-risk: med | footprint: in-story
- evidence: Install.Smoke.CheckAreaLists reads every area list at maxRows=1; the Vendor cap trap matrix row says MaxRows never bounds the vendor SQL, and the port's ASYNCTIMEOUT is 30 s
- 2026-09-15T03:41:51Z status=wontfix-accepted owner=2-10-the-audit-database-viewer-with-its-agent-marker-filter by=cr note=measured: passes on live ocupilot's 89,318 rows and on a clean throwaway; bounding it needs a per-screen smoke criterion the check does not have; reopen_if=the audit area-list check times out or exceeds a second on a populated instance

### DW-286: No executing test pins the route handler's own criteria allow-list: replacing ScreenRead.Handle's CriteriaParams loop with one that forwards every request key reddens nothing
- source: spec-2-10-the-audit-database-viewer-with-its-agent-marker-filter.md | severity: low | fix-risk: low | footprint: in-story
- evidence: Test.ScreenRead has no criteria coverage and Test.ReadTool drives the tool path; a route-tier pin needs a criteria-bearing fixture descriptor, which ripples through the fixture registry's roster assertions
- 2026-09-15T03:41:54Z status=wontfix-theoretical owner=2-10-the-audit-database-viewer-with-its-agent-marker-filter by=cr note=applied that mutation on the throwaway and observed no change at all - SeedCriteria is a second, structural allow-list that reads only declared params, so the route loop is the outer of two layers; real only if a caller value is ever taken from the request outside SeedCriteria

### DW-287: An operator who redirects the console log with the console or ConsoleFile configuration parameter moves messages.log out of the manager directory, and the endpoint would read an absent or stale file there
- source: spec-2-11-the-messages-log-paging-endpoint.md | severity: low | fix-risk: low | footprint: in-epic
- evidence: the endpoint resolves $System.Util.ManagerDirectory() per call by design (AC2 forbids a caller-supplied path); the classic portal follows the configured redirect instead
- 2026-09-15T03:57:27Z status=wontfix-accepted owner=2-11-the-messages-log-paging-endpoint by=spec_gate note=reopen_if=an operator reports the viewer showing nothing or stale lines while the classic log page shows the live file

### DW-288: The LOG.SOURCE refusal is reachable only at the port's own API, never over the wire, because the route is literal and binds the source key itself
- source: spec-2-11-the-messages-log-paging-endpoint.md | severity: low | fix-risk: low | footprint: in-epic
- evidence: the route is /logs/messages rather than /logs/:source, so no HTTP caller can name an unknown source until a second source ships
- 2026-09-15T03:57:27Z status=wontfix-accepted owner=2-11-the-messages-log-paging-endpoint by=spec_gate note=reopen_if=a second log source ships and the route takes the source from the caller, at which point the refusal needs a wire test
- 2026-09-15T05:55:24Z note=partial reopen check 2026-09-15: a second log source did ship with Story 2.12, but every route still binds its own source key, so the LOG.SOURCE refusal is still unreachable over the wire and the entry stays closed

### DW-289: OcuPilot.Test.WireSecurityRead creates nine IRIS users and roles on whatever instance a package-discovery run points at, with only a doc comment keeping it off a live one
- source: spec-2-11-the-messages-log-paging-endpoint.md | severity: med | fix-risk: low | footprint: out-of-footprint
- evidence: ui/tools/ci-runner.mjs selects test classes by package, so node ui/tools/ci-runner.mjs --container ocupilot runs it against the live instance; Story 2.11 closed the identical exposure on LogSourceRotation and LogSourceDenial with a runtime arming variable, leaving this the last unguarded destructive class
- 2026-09-15T05:37:30Z status=routed owner=burndown by=cr note=same three-line guard as LogSourceDenial (OCUPILOT_ALLOW_PRINCIPALS, set only by scripts/ci-throwaway.sh); distinct from DW-48, which is about test classes being compiled into production at all
- 2026-09-15T08:26:32Z owner=2-13-epic-2-burn-down by=burndown note=chartered into the Epic 2 burn-down story
- 2026-09-15T08:38:21Z note=scope correction 2026-09-15 (spec_gate, measured): WireSecurityRead is not the only unguarded class - Wire, Token, State, Version and UnexpireScope also create and delete principals on whatever instance ci-runner points at, and EnsurePrincipal deletes a pre-existing account of the same name first; Story 2.13 guards all six and adds a check-objectscript rule
- 2026-09-15T11:46:01Z status=resolved-by:2-13-epic-2-burn-down by=adjudication note=six principal-creating classes now refuse to run without OCUPILOT_ALLOW_PRINCIPALS, a check-objectscript rule enforces it, and review tightened the rule so a guard that never refuses no longer satisfies it

### DW-290: OcuPilot.Test.LogSourceRotation.Head reads a byte count but is called with a character count, so a non-ASCII byte in the rotated-in log reddens a correct page
- source: spec-2-11-the-messages-log-paging-endpoint.md | severity: low | fix-risk: med | footprint: in-story
- evidence: Head(pWant) reads and extracts pWant bytes then UTF-8 decodes; both call sites pass $Length(tServed), which counts characters, and a sequence split at the extract boundary decodes to ?; LogSourceWire.ServedBytes's own doc states the log is not pure ASCII
- 2026-09-15T05:37:35Z status=wontfix-accepted owner=2-11-the-messages-log-paging-endpoint by=cr note=reopen_if=LogSourceRotation reddens on its served-region assertion while restarted and the generation count are correct; fixing it means choosing a byte-or-character contract and can only be verified on a throwaway

### DW-291: The identity token is not bound to the source key, so a cursor issued for one log source would be honoured for another whose first line is byte-identical
- source: spec-2-11-the-messages-log-paging-endpoint.md | severity: low | fix-risk: low | footprint: in-epic
- evidence: LogSourcePort.Identity hashes only the file's first line; unreachable today because SOURCES holds one key and the route binds it, and the two files 2.12 introduces have different line formats
- 2026-09-15T05:37:35Z status=wontfix-theoretical owner=2-11-the-messages-log-paging-endpoint by=cr note=what would make it real: a second source whose file's first line can equal another source's; the one-line guard is to hash pSource with the prefix
- 2026-09-15T05:55:24Z note=evidence correction 2026-09-15 (by=spec_gate, Story 2.12 plan): the entry says 'the two files 2.12 introduces' - Story 2.12 introduces no log files; it reads SYS.ApplicationError queries, so the claim's subject is wrong while the finding it names stands on its own files

### DW-292: README's smoke-check enumeration has no pin and is two checks behind the class it describes
- source: spec-2-11-the-messages-log-paging-endpoint.md | severity: low | fix-risk: low | footprint: in-epic
- evidence: README.md's smoke paragraph lists four of the six CheckAreaLists reads; processes (Story 2.9) and audit (Story 2.10) were never added, and nothing reddens when Install.Smoke gains a check
- 2026-09-15T05:37:35Z status=wontfix-accepted owner=2-11-the-messages-log-paging-endpoint by=cr note=reopen_if=a release reader follows the README's list and misses a check the smoke actually runs; the durable fix is a pin in ui/tools, not another hand-edited sentence

### DW-293: Every level of the application error log computes truncated and the client drops it, so a list cut at the 1,000-row default renders on screen as the complete set
- source: spec-2-12-the-application-error-log-endpoint-and-drill-down.md | severity: med | fix-risk: low | footprint: in-epic
- evidence: the port returns truncated per level; error-log.store.ts does not carry it and the page shows no cap notice, unlike the shared data table
- 2026-09-15T07:50:14Z status=routed owner=burndown by=harvest note=carry truncated into the drill store and show the table's cap notice, or say in the empty/footer line that the level is cut
- 2026-09-15T08:26:31Z owner=2-13-epic-2-burn-down by=burndown note=chartered into the Epic 2 burn-down story
- 2026-09-15T11:46:01Z status=resolved-by:2-13-epic-2-burn-down by=adjudication note=every error-log level carries truncated to the client and renders the cap notice; a browser leg drives a genuinely truncated level

### DW-294: The shell's command bar renders an inert Filter rows input and an empty count region on the application error log, the first built screen that declares no read
- source: spec-2-12-the-application-error-log-endpoint-and-drill-down.md | severity: low | fix-risk: low | footprint: in-epic
- evidence: command-bar.ts renders the filter whenever a screen is bound; the drill-down screen has no table to filter
- 2026-09-15T07:50:14Z status=routed owner=burndown by=harvest note=hide the filter and the count region on a screen that declares no read, or give the drill levels a filter that works
- 2026-09-15T08:26:04Z status=wontfix-accepted owner=2-12-the-application-error-log-endpoint-and-drill-down by=burndown note=reopen_if=a second read-less screen ships, or a user reports typing into the filter on a drill-down screen and nothing happening; a LOW may not be owned by the burn-down (Rule 15)

### DW-295: The tool registry's two sources expose different View arities and Screen.Tool.Base declares no View at all, so a dispatcher must discover the difference at runtime
- source: spec-2-12-the-application-error-log-endpoint-and-drill-down.md | severity: med | fix-risk: low | footprint: out-of-footprint
- evidence: descriptor-derived read tools and class tools (logs.applicationerrors.read) answer View with different signatures; Base declares none
- 2026-09-15T07:50:14Z status=routed owner=4-2-the-tool-registry-its-one-gate-point-and-the-three-shell-rea by=harvest note=Story 4.2 builds the dispatcher: declare View on Screen.Tool.Base so both sources satisfy one signature, or have the dispatcher key on KIND

### DW-296: The client bundle is 511.45 kB against Angular's 500 kB warning budget, so every build prints a budget warning that no longer means anything
- source: spec-2-12-the-application-error-log-endpoint-and-drill-down.md | severity: low | fix-risk: low | footprint: in-epic
- evidence: ui/angular.json declares the 500 kB warning and a 1 MB error budget; the build passes but warns on every run
- 2026-09-15T07:50:14Z status=routed owner=burndown by=harvest note=set a budget the project actually intends (raise the warning and keep an error budget that would catch a real regression), rather than leaving a warning everyone learns to ignore
- 2026-09-15T08:26:04Z status=wontfix-accepted owner=2-12-the-application-error-log-endpoint-and-drill-down by=burndown note=reopen_if=the bundle crosses the 1 MB error budget, or a release story needs a budget that means something; a LOW may not be owned by the burn-down (Rule 15)

### DW-297: Every named refusal on the application error log renders one generic sentence, so a purged date, an unknown entry and a privilege denial read identically on screen
- source: spec-2-12-the-application-error-log-endpoint-and-drill-down.md | severity: med | fix-risk: high | footprint: in-story
- evidence: error-log.page.ts renders STRINGS.connectivityRequestRefused for LOG.NAMESPACE, LOG.DATE, LOG.ENTRY, LOG.MAXROWS and AUTH.NOPRIVILEGE alike; the fault's code reaches the store via classifyFault and is discarded, and Api/Error.cls's LOGDATE doc says the screen turns it into 'this date is gone'
- 2026-09-15T08:23:40Z status=escalated owner=burndown by=cr note=branching on fault.code needs three new EXPERIENCE.md Fixed-strings rows (a product call) plus the citation/line-pin cascade DW-272 tracks; same blocker as DW-293
- 2026-09-15T11:47:35Z status=routed owner=3-0-epic-2-deferred-cleanup by=merge_gate note=owner-delegated decision 2026-09-15: a refusal that cannot be told from another is the defect this product exists to correct, so each named refusal gets its own published sentence - the privilege denial reuses the Fixed strings 403 pattern, and a purged date and an unknown entry get rows of their own, added in the same pass as the code so the strings cardinality holds
- 2026-09-15T13:37:44Z status=resolved-by:3-0-epic-2-deferred-cleanup by=adjudication note=refusalMessage picks the sentence from the envelope's machine code (AD-39): one published sentence each for LOG.NAMESPACE, LOG.DATE and LOG.ENTRY, the existing You need <resource> to <action> pattern for AUTH.NOPRIVILEGE naming its pair, and the generic sentence only as the default arm; a browser leg drives a real 403 with a failing pair to the rendered page

### DW-298: The class tool's View contract drops the port's http status and fault, and lets a model-supplied maxRows reach the port unbounded by the context cap
- source: spec-2-12-the-application-error-log-endpoint-and-drill-down.md | severity: med | fix-risk: low | footprint: out-of-footprint
- evidence: Screen/Tool/ErrorRead.View returns only a %Status, so a dispatcher cannot tell a 403 from a 404 or name the failing pair (AD-39's machine half); and it passes tArgs maxRows straight to Errors while DESCRIPTION advertises no ceiling, so the port materialises that many rows before View keeps pContextCap
- 2026-09-15T08:23:42Z status=routed owner=4-2-the-tool-registry-its-one-gate-point-and-the-three-shell-rea by=cr note=Story 4.2 owns dispatch by this story's own contract; settle the result shape there, beside DW-295's View arity

### DW-299: The date-ordering sweep compares nothing on the CI throwaway, which carries exactly one error date, so a reordering at the port would ship green through CI
- source: spec-2-12-the-application-error-log-endpoint-and-drill-down.md | severity: low | fix-risk: med | footprint: in-story
- evidence: ci-throwaway.sh wipes the volume on every up and the installer seeds one entry per start, so every seeded error lands on today; Test.ErrorLog and Test.ErrorLogWire both compare each row with the one before it and record nothing with one row
- 2026-09-15T08:23:52Z status=wontfix-accepted owner=2-12-the-application-error-log-endpoint-and-drill-down by=cr note=reopen_if=a story adds sorting or paging at the port, or the throwaway gains a second error date; closing it needs a stub SYS.ApplicationError query class behind QueryClass()

### DW-300: AC1's no-^ERRORS half has no witness: the query counter catches a projection that reads the global instead of the query, not one that reads it as well
- source: spec-2-12-the-application-error-log-endpoint-and-drill-down.md | severity: low | fix-risk: med | footprint: in-story
- evidence: AC1 names a source-level check over the story's files that does not exist; check-objectscript.py reports 16 rules and the spec's own Verification asserts that count, so a seventeenth rule moves a number the spec pins
- 2026-09-15T08:23:52Z status=wontfix-accepted owner=2-12-the-application-error-log-endpoint-and-drill-down by=cr note=reopen_if=a projection is found reading ^ERRORS alongside the query, which the counter cannot see

### DW-301: Walking Back to the namespaces level drops keyboard focus to the body, because the control the user just activated is removed
- source: spec-2-12-the-application-error-log-endpoint-and-drill-down.md | severity: low | fix-risk: med | footprint: in-story
- evidence: error-log.page.ts renders the Back button under @if (canGoBack), false at the namespaces level, so the activated element leaves the DOM with no focus target declared to receive it
- 2026-09-15T08:23:52Z status=wontfix-accepted owner=2-12-the-application-error-log-endpoint-and-drill-down by=cr note=reopen_if=EXPERIENCE.md gains a focus contract for drill levels, or NFR-12 keyboard review reaches this screen

### DW-302: audit.browser-spec.mjs's seedAuditRows races the audit log's own write visibility, so the whole file fails on the first browser run against a freshly created throwaway and passes on every re-run
- source: spec-2-13-epic-2-burn-down.md | severity: med | fix-risk: low | footprint: in-epic
- evidence: seeds 1000 rows and re-counts 822; seven cases in that file fail on a fresh throwaway, which is exactly what CI creates
- 2026-09-15T10:34:38Z status=open owner=2-13-epic-2-burn-down by=harvest note=wait for the seeded count to settle before asserting, or seed through a path whose visibility is synchronous
- 2026-09-15T11:46:01Z status=resolved-by:2-13-epic-2-burn-down by=adjudication note=seedAuditRows polls the count until it settles; verified green on a genuinely fresh throwaway, the condition that used to fail

### DW-303: The principal-guard checker rule is not pinned against any real class, and instance mutation that goes through OcuPilot.Install.Installer is outside it entirely
- source: spec-2-13-epic-2-burn-down.md | severity: med | fix-risk: low | footprint: in-epic
- evidence: the new check-objectscript rule has no positive case over a guarded class and does not see installer-mediated mutation
- 2026-09-15T10:34:38Z status=open owner=2-13-epic-2-burn-down by=harvest note=pin the rule against a real guarded class and say in the rule what it does not cover
- 2026-09-15T11:46:01Z status=resolved-by:2-13-epic-2-burn-down by=adjudication note=the checker rule is pinned against the real shipped LogSourceDenial class, and review added four cases so a guard that never refuses fails the rule

### DW-304: The three Task Manager status literals are pinned only against a typed copy of themselves, and the Not running case is never exercised end to end
- source: spec-2-13-epic-2-burn-down.md | severity: med | fix-risk: low | footprint: in-epic
- evidence: the banner corpus compares the descriptor's literals with the same literals in the test; no throwaway leg stops the Task Manager
- 2026-09-15T10:34:38Z status=open owner=2-13-epic-2-burn-down by=harvest note=drive the stopped case on the throwaway, or pin the literals against the vendor's own vocabulary
- 2026-09-15T11:46:01Z status=resolved-by:2-13-epic-2-burn-down by=adjudication note=the banner literals are pinned against the vendor's own compiled RunGet source, and a fixture resolves the stopped value end to end

### DW-305: AdminPort.QUERYPAIRS is a declared vocabulary with no grammar, no corpus and no checker, unlike every other declared vocabulary in the tree
- source: spec-2-13-epic-2-burn-down.md | severity: med | fix-risk: low | footprint: in-epic
- evidence: DW-274's per-endpoint any-of pair declaration is a bare parameter; a misspelled resource would declare nothing and refuse nothing
- 2026-09-15T10:34:38Z status=open owner=2-13-epic-2-burn-down by=harvest note=give it the corpus-and-refusal treatment the descriptor vocabularies have
- 2026-09-15T11:46:01Z status=resolved-by:2-13-epic-2-burn-down by=adjudication note=QueryPairsProblem plus Test/QueryPairCorpus.cls give QUERYPAIRS the grammar, corpus and instance-side resolution check the other declared vocabularies have

### DW-306: Registry.DeclarationProblem's call site inside Registry.Validate is pinned on the client side only, so deleting the ObjectScript call reddens nothing
- source: spec-2-13-epic-2-burn-down.md | severity: med | fix-risk: low | footprint: in-epic
- evidence: the closed-key-set refusal is observed through screen-mirror; no instance test drives Validate over a descriptor with an unknown top-level key
- 2026-09-15T10:34:38Z status=open owner=2-13-epic-2-burn-down by=harvest note=add the instance-side case to the descriptor corpus run
- 2026-09-15T11:46:01Z status=resolved-by:2-13-epic-2-burn-down by=adjudication note=ReadTool drives Validate over a descriptor with an unknown top-level key, so deleting the ObjectScript call now reddens

### DW-307: Three verification steps the burn-down spec promised were not written: a browser leg for scroll preservation on Refresh, a browser leg on a truncated error-log level, and the throwaway real-principal observation of the port's named 403
- source: spec-2-13-epic-2-burn-down.md | severity: med | fix-risk: low | footprint: in-epic
- evidence: the ## Verification section lists them; the tests do not exist
- 2026-09-15T10:34:38Z status=open owner=2-13-epic-2-burn-down by=harvest note=write the three legs, or strike them from Verification with a reason
- 2026-09-15T11:44:05Z status=open owner=2-13-epic-2-burn-down by=cr note=leg 3 declining reason does not hold: a recorded+reverted Rule 19 window is how a shipped class is mutated
- 2026-09-15T11:46:10Z status=routed owner=3-0-epic-2-deferred-cleanup by=adjudication note=Epic 2 overflow: two of the three promised legs were written; the third (a throwaway real-principal observation of AdminPort's own 403) is carried to Epic 3's cleanup story, with the reviewer's correction that a recorded and reverted mutation window is the sanctioned way to exercise it
- 2026-09-15T13:37:44Z status=resolved-by:3-0-epic-2-deferred-cleanup by=adjudication note=the descriptor-only window on the throwaway observed status 403, code PORT.ACCESSDENIED and detail.failedPair %Admin_Manage:USE over HTTP with a real principal, and WireSecurityRead's mutation paragraph now records exactly what reddened

### DW-308: Browser-spec residue from the burn-down: a viewport left at 420px, an approximate FOCUSABLE selector, a two-evaluate race in clickRowCentre, and two routes not measured by the element the AC names
- source: spec-2-13-epic-2-burn-down.md | severity: low | fix-risk: low | footprint: in-epic
- evidence: residue noted by the implement pass's own review
- 2026-09-15T10:34:38Z status=wontfix-accepted owner=2-13-epic-2-burn-down by=harvest note=reopen_if=a browser leg flakes or a viewport-dependent assertion fails on CI's runner

### DW-309: The citation gate covers EXPERIENCE.md only, walks code trees only, and cannot reach a continuation reference that names no document
- source: spec-2-13-epic-2-burn-down.md | severity: low | fix-risk: low | footprint: in-epic
- evidence: the new gate anchors EXPERIENCE.md citations by quoted phrase; DESIGN.md, the PRD and bare ':n' continuations are outside it
- 2026-09-15T10:34:38Z status=wontfix-accepted owner=2-13-epic-2-burn-down by=harvest note=reopen_if=a review finding is traced to a stale citation the gate does not cover
- 2026-09-15T11:44:05Z occurrence=2-13-epic-2-burn-down
- 2026-09-15T13:36:09Z occurrence=3-0-epic-2-deferred-cleanup note=reopen_if fired: four .cls:n cites in this story's own evidence record went stale by three lines, written by the pass that moved them
- 2026-09-15T13:36:09Z status=routed owner=burndown by=cr note=recorded severity low understates it; no gate resolves a .cls:n or a spec-markdown citation, and the probe fired inside a single story

### DW-310: CLAUDE.md says check-objectscript.py has 16 rules and the checker's module docstring stops describing rules at 15, while CHECKS now holds 17
- source: spec-2-13-epic-2-burn-down.md | severity: low | fix-risk: low | footprint: in-story
- evidence: the rule count is stated in two places and the new principal-guard rule updated neither
- 2026-09-15T10:34:38Z status=open owner=2-13-epic-2-burn-down by=harvest note=correct both counts in the same pass that added the rule
- 2026-09-15T11:46:01Z status=resolved-by:2-13-epic-2-burn-down by=adjudication note=CLAUDE.md and the checker's module docstring both name 17 rules

### DW-311: Test/ReadBanner/Matching couples a unit test to the live instance's Task Manager state
- source: spec-2-13-epic-2-burn-down.md | severity: low | fix-risk: low | footprint: in-epic
- evidence: the fixture's equals value matches whatever the live Task Manager currently reports
- 2026-09-15T10:34:38Z status=wontfix-accepted owner=2-13-epic-2-burn-down by=harvest note=reopen_if=the class fails on an instance whose Task Manager is suspended or stopped
- 2026-09-15T11:44:05Z occurrence=2-13-epic-2-burn-down

### DW-312: AdminPort.Denied answers HTTP 403 with an INTERNAL/server_error envelope when Fault.Outcome itself returns an error
- source: spec-2-13-epic-2-burn-down.md | severity: low | fix-risk: low | footprint: in-story
- evidence: Outcome leaves pFault as the internal default on its own error path, and Denied forwards that default under a forced 403, unlike Fail which derives status and mapping from one value
- 2026-09-15T11:44:09Z status=wontfix-theoretical owner=2-13-epic-2-burn-down by=cr note=unreachable today: Normalize errors only on an OK status, and the probe branch guarantees an error one; real if a future caller passes an OK status to Denied

### DW-313: check-objectscript.py's method_body counts braces without skipping string literals, so a brace inside a message would mis-terminate OnBeforeAllTests
- source: spec-2-13-epic-2-burn-down.md | severity: low | fix-risk: low | footprint: in-story
- evidence: method_body scans raw text for depth 0; a guard message containing an unbalanced brace would truncate the body and report a guarded class as unguarded
- 2026-09-15T11:44:09Z status=wontfix-theoretical owner=2-13-epic-2-burn-down by=cr note=no guard message in the tree contains a brace; real the first time one does, and it fails closed (blocks the commit) rather than open

### DW-314: DESTRUCTIVE_TEST_RE matches only the ##class() spelling, so a principal reached through $ClassMethod evades the guard rule
- source: spec-2-13-epic-2-burn-down.md | severity: low | fix-risk: low | footprint: in-story
- evidence: the rule's own header states it reads the APIs the tree actually calls; no $ClassMethod('Security.Users',...) form exists under Test/ today
- 2026-09-15T11:44:09Z status=wontfix-theoretical owner=2-13-epic-2-burn-down by=cr note=real the first time a Test class reaches a principal API by indirection; reopen_if a destructive Test class passes check-objectscript.py

### DW-315: The command box would list two Refresh rows sharing one DOM id if a screen ever declared primaryAction.id 'refresh'
- source: spec-2-13-epic-2-burn-down.md | severity: low | fix-risk: low | footprint: in-story
- evidence: command-box.ts pushes REFRESH_ACTION_ID and then the primary action without excluding it; no Epic 2 screen declares a primaryAction at all
- 2026-09-15T11:44:14Z status=wontfix-theoretical owner=2-13-epic-2-burn-down by=cr note=real the first time a descriptor names its primary action 'refresh'; reopen_if a duplicate ocu-command-box-action-refresh id appears

### DW-316: app.ts's arrival focus treats document.documentElement as focus a user placed, so a frame arriving with it active leaves focus outside the frame
- source: spec-2-13-epic-2-burn-down.md | severity: low | fix-risk: low | footprint: in-story
- evidence: the unplaced test is active === null || active === document.body; Chrome and jsdom both report body, so documentElement is not produced by any path observed here
- 2026-09-15T11:44:14Z status=wontfix-theoretical owner=2-13-epic-2-burn-down by=cr note=real on an engine that reports documentElement after a focused element is removed; reopen_if the DW-248 browser leg fails with activeElement HTML

### DW-317: No browser leg clicks Refresh on logs/errors, so the drill's own registration is pinned only against a NavigationService stub that always resolves the screen
- source: spec-2-13-epic-2-burn-down.md | severity: low | fix-risk: low | footprint: in-story
- evidence: error-log.page.spec's stub returns ERROR_LOG_SCREEN unconditionally; the only .ocu-command-bar-refresh-action browser leg is on the tasks route
- 2026-09-15T11:44:14Z status=wontfix-accepted owner=2-13-epic-2-burn-down by=cr note=reopen_if Refresh is reported missing on logs/errors in a real browser, or screenForUrl stops resolving that route

### DW-318: A refused manual Refresh on the error-log drill draws the refusal over the previous read's rows and its cap notice
- source: spec-2-13-epic-2-burn-down.md | severity: low | fix-risk: med | footprint: in-story
- evidence: reopen() deliberately keeps the rows so Refresh stays silent, and read()'s fault branch never clears them; a LOG.DATE 404 then reads 'this date is gone' above rows for that date
- 2026-09-15T11:44:14Z status=wontfix-accepted owner=2-13-epic-2-burn-down by=cr note=keeping last-good data under a named refusal matches every other list's refresh; reopen_if a user reports acting on rows a refusal had invalidated

### DW-319: Screen/Tool/Registry.cls's new maxLength shape check has no executed test host, so its refusal sentence is written and never driven
- source: spec-2-13-epic-2-burn-down.md | severity: low | fix-risk: low | footprint: in-story
- evidence: the sentence 'maxLength is not a whole number above zero' occurs only at its definition; the only producer is Screen/Tool/Read.cls, which sets the number type hint
- 2026-09-15T11:44:18Z status=wontfix-accepted owner=2-13-epic-2-burn-down by=cr note=reopen_if a second producer writes the tool schema, or the number type hint at Screen/Tool/Read.cls is dropped

### DW-320: screen-height.browser-spec.mjs's waitForRows times out naming nothing when a route lists no rows on the throwaway
- source: spec-2-13-epic-2-burn-down.md | severity: low | fix-risk: low | footprint: in-story
- evidence: the AC-A case per route waits for a row selector with no precondition assertion, so an instance with no SSL configuration reports a timeout rather than the missing fixture
- 2026-09-15T11:44:18Z status=wontfix-accepted owner=2-13-epic-2-burn-down by=cr note=reopen_if an AC-A case times out on CI and the cause has to be found by hand

### DW-321: Test/NarrowArea.cls is the only fixture descriptor directly under OcuPilot.Test., so any registry ever pointed at that bare package would take it into a roster it was not designed for
- source: spec-2-13-epic-2-burn-down.md | severity: low | fix-risk: low | footprint: in-story
- evidence: every other fixture registry names a sub-package; NarrowArea is validated by calling DeclarationProblem and AreaCoverageProblem directly, never through Validate over a roster
- 2026-09-15T11:44:18Z status=wontfix-theoretical owner=2-13-epic-2-burn-down by=cr note=real the first time a fixture registry returns bare 'OcuPilot.Test.'; reopen_if a fixture roster reports NarrowArea

### DW-322: WireSecurityRead's Mutation paragraph still asserts an unobserved second mutation - the descriptor pair swap - in the very paragraph DW-307 was opened about
- source: spec-3-0-epic-2-deferred-cleanup.md | severity: med | fix-risk: low | footprint: in-story
- evidence: the paragraph now records the observed window but keeps a second claim nobody ran
- 2026-09-15T13:04:16Z status=open owner=3-0-epic-2-deferred-cleanup by=harvest note=observe it or strike it; an unobserved claim in a mutation paragraph is what DW-307 was about
- 2026-09-15T13:21:34Z status=resolved-by:3-0-epic-2-deferred-cleanup by=qa note=swap observed on ocupilot-ci: only SECUREUSER's ScreensFor assertion (:389) reddens, AreaVerdictFor (:390) stays green; WireSecurityRead.cls Mutation paragraph corrected to state it
- 2026-09-15T13:36:09Z note=cite correction (cr): SECUREUSER ScreensFor is WireSecurityRead.cls:392 and AreaVerdictFor :393 in the committed tree, not :389/:390 - the QA doc-comment rewrite moved them after the note was written

### DW-323: The privilege-denial refusal sentence is never rendered from a real envelope: the browser leg covers the 404 LOG.NAMESPACE arm only
- source: spec-3-0-epic-2-deferred-cleanup.md | severity: med | fix-risk: low | footprint: in-story
- evidence: refusalMessage's AUTH.NOPRIVILEGE arm is pinned in jsdom over a stub; no leg drives a real 403 with a failing pair to the screen
- 2026-09-15T13:04:16Z status=open owner=3-0-epic-2-deferred-cleanup by=harvest note=drive a real principal's 403 to the error log screen on the throwaway, the same shape AC4's window already creates
- 2026-09-15T13:21:34Z status=resolved-by:3-0-epic-2-deferred-cleanup by=qa note=browser leg added driving ErrorLogDenial's SERVEDUSER to a real AUTH.NOPRIVILEGE with detail.failedPair on ocupilot-ci; mutation demonstrated and reverted

### DW-324: The error log's three absence sentences name the drill level the log refused, but refusalMessage branches on code alone, so a LOG.NAMESPACE at list/detail sends the reader to a list Back reaches in two or three presses rather than one
- source: spec-3-0-epic-2-deferred-cleanup.md | severity: low | fix-risk: low | footprint: in-story
- evidence: LogSourcePort.ErrorsRead checks NamespaceHeld for every level but namespaces and DateHeld for list/detail; the Back control renders during the refusal and back() walks one level per press, so the advice converges instead of dead-ending
- 2026-09-15T13:36:12Z status=wontfix-accepted owner=3-0-epic-2-deferred-cleanup by=cr note=the fix is a level branch (swapping an accurate sentence for the request-refused fragment) or a copy rewrite, both product calls; reopen_if=a session shows the sentence naming a list Back does not reach and the user stops rather than pressing Back again

### DW-325: connectivityRequestRefused is the status-strip fragment 'request refused', not a sentence, and LogSourcePort's pairless 403 is a shipped path that renders it inline on the error log
- source: spec-3-0-epic-2-deferred-cleanup.md | severity: low | fix-risk: low | footprint: in-story
- evidence: LogSourcePort.cls:609 denies with no pair, so refusalMessage's default arm renders the fragment as the screen's whole answer; every other arm now publishes a sentence
- 2026-09-15T13:36:12Z status=wontfix-accepted owner=3-0-epic-2-deferred-cleanup by=cr note=pre-existing published copy the story's intent explicitly preserves; changing it needs an EXPERIENCE.md row edit and is a product copy decision; reopen_if=a user reports the bare fragment on the unresolvable-namespace path

### DW-326: The DW-323 browser leg hand-copies two values ErrorLogDenial already owns: the SERVEDUSER account name as a literal, and the failed pair as REFUSEDRESOURCE concatenated with :WRITE
- source: spec-3-0-epic-2-deferred-cleanup.md | severity: low | fix-risk: low | footprint: in-story
- evidence: ui/browser/error-log.browser-spec.mjs marshals four Prepared* values out of the class through mark() but declares SERVED_USER as a literal; ErrorLogDenial already holds PreparedDbFailedPair for exactly the prediction the leg repeats
- 2026-09-15T13:36:17Z status=wontfix-accepted owner=3-0-epic-2-deferred-cleanup by=cr note=fails loudly at sign-in rather than silently, and the fix is a test-only change the review pass cannot execute without the throwaway; reopen_if=ErrorLogDenial's SERVEDUSER parameter or its WRITE permission spelling changes and the browser leg fails with no pointer to the cause

### DW-327: WireSecurityRead's rewritten Mutation doc comment names two ledger ids and a story number, and doubled from six lines to twelve, in a story whose spec is flagged oversized
- source: spec-3-0-epic-2-deferred-cleanup.md | severity: low | fix-risk: low | footprint: in-story
- evidence: the paragraph carries (Story 3.0, DW-307) and (Story 3.0, DW-322); CLAUDE.md Prose discipline says a doc comment does not name review rounds, finding ids or iteration numbers, and that history belongs in the spec's Review Triage Log
- 2026-09-15T13:36:17Z status=wontfix-accepted owner=3-0-epic-2-deferred-cleanup by=cr note=the recipe and the observation are correct and checkable; stripping the ids means editing and recompiling a shipped class that runs only on the throwaway, which is disproportionate here; reopen_if=the paragraph grows again, or its ids outlive the ledger entries they name

### DW-328: StubApi's installing arm is a third JsonResult shape the double gained in this story, and nothing in the suite compares the double against the real ApiService
- source: spec-3-0-epic-2-deferred-cleanup.md | severity: low | fix-risk: low | footprint: in-story
- evidence: the story's own followup_review_recommended names this risk and no ledger entry carried it; review checked the arm byte-for-byte against api.ts's installing arm and it matches today, so the risk is drift, not a present defect
- 2026-09-15T13:36:17Z status=wontfix-accepted owner=3-0-epic-2-deferred-cleanup by=cr note=reopen_if=the real JsonResult installing arm gains or renames a field and StubApi.install still compiles, leaving the not-installed leg green against a shape the client no longer receives

### DW-329: The definition change record masks maxTokens, because Kernel/Audit/Log's redactor matches a credential name as a substring and its list contains token
- source: spec-3-1-agent-definitions-and-the-rules-that-keep-them-honest.md | severity: med | fix-risk: low | footprint: in-epic
- evidence: Log.IsCredentialName('maxTokens') answers 1 on the instance; Story 3.8 builds its audit row on the same change record
- 2026-09-15T14:40:08Z status=routed owner=3-8-every-configuration-change-is-resource-gated-and-audited by=harvest note=anchor the redactor's match the way the build-time credential pattern is anchored (suffix or exact name), so a bound is not mistaken for a secret

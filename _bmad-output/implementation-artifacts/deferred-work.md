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

### DW-3: Container restarts and upgrades OcuPilot while a browser holds the old bundle
- source: epics-review-findings.json | severity: med | fix-risk: low | footprint: in-story
- evidence: Old SPA calls an upgraded API and fails in undefined ways [epics-review edge-case-hunter E4; epics.md:1074-1076 @8981cdf]
- 2026-09-09T15:10:47Z status=routed owner=1-5-the-static-shell-serves-the-spa-including-deep-links by=load note=edge-case-hunter lens, pre-planning route; address in Tasks & Acceptance or decline under Design Notes. guard: AC: the API returns its build stamp; a mismatched client is prompted to reload
- 2026-09-12T01:32:13Z status=routed owner=1-8-instance-identity-and-the-api-version-guard by=adjudication note=HALF closed: index.html no-store and hashed assets immutable are delivered and pinned by Test.Static. NOT closed: the API reporting its build stamp and the client prompting a mismatched bundle to reload
- 2026-09-12T08:27:50Z status=decision-pending owner=burndown by=spec_gate note=server half is in 1.8 (buildIdentity on the instance response). The client reload prompt needs two things this project does not have: UX copy in neither DESIGN.md nor EXPERIENCE.md, and a real build identity (Installer.cls:73 is the literal 'dev'). Owner call at the decision sheet
- 2026-09-12T09:46:32Z occurrence=1-8-instance-identity-and-the-api-version-guard

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

### DW-12: Neither HSCUSTOM nor USER exists, or the documented override names a missing namespace
- source: epics-review-findings.json | severity: med | fix-risk: low | footprint: in-story
- evidence: Install fails obscurely or lands in an unintended namespace [epics-review edge-case-hunter E13; epics.md:1424-1427 @8981cdf]
- 2026-09-09T15:10:48Z status=routed owner=1-16-the-ipm-module-generated-from-one-roster by=load note=edge-case-hunter lens, pre-planning route; address in Tasks & Acceptance or decline under Design Notes. guard: AC: install validates the target namespace exists and fails loudly naming it

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

### DW-18: Active row vanishes on a silent re-fetch or filter change, not a delete
- source: epics-review-findings.json | severity: med | fix-risk: low | footprint: in-story
- evidence: aria-activedescendant points at a recycled row and focus is lost [epics-review edge-case-hunter E19; epics.md:1600-1604 @8981cdf]
- 2026-09-09T15:10:48Z status=routed owner=2-4-the-data-table by=load note=edge-case-hunter lens, pre-planning route; address in Tasks & Acceptance or decline under Design Notes. guard: AC: any re-fetch dropping the active row moves focus and selection exactly as a delete does

### DW-19: messages.log absent, unreadable, or the manager directory moved between calls
- source: epics-review-findings.json | severity: med | fix-risk: low | footprint: in-story
- evidence: Viewer shows an empty log, implying the instance logged nothing [epics-review edge-case-hunter E20; epics.md:1778-1788 @8981cdf]
- 2026-09-09T15:10:48Z status=routed owner=2-11-the-messages-log-paging-endpoint by=load note=edge-case-hunter lens, pre-planning route; address in Tasks & Acceptance or decline under Design Notes. guard: AC: a missing or unreadable source returns a named refusal, distinct from an empty page

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

### DW-36: CLAUDE.md's Running-and-verifying section is stale: it does not mention check-objectscript.py, now a commit-blocking gate, and still says the Angular build and test invocations are a TODO
- source: spec-1-1-the-workspace-the-pinned-stack-and-one-response-envelope.md | severity: med | fix-risk: low | footprint: in-epic
- evidence: CLAUDE.md 'Running and verifying' documents only scripts/lint-docs.sh and carries 'TODO once code exists: the Angular build and test invocations', but this story added scripts/check-objectscript.py to .githooks/pre-commit and created ui/ with npm run build and node --test tools/. CLAUDE.md is the first file every agent reads, so a later story's spawn inherits an understated gate list. Deferred rather than patched because step-04 routes any fix that edits an agent-context file to defer.
- 2026-09-09T17:56:40Z status=routed owner=burndown by=cr note=no single story owns CLAUDE.md; fold into the epic burn-down alongside the other repo-hygiene items
- 2026-09-11T13:27:48Z occurrence=1-4-one-command-brings-up-an-instance-with-ocupilot-installed
- 2026-09-11T13:27:48Z by=cr note=CLAUDE.md's intro still says src/OcuPilot/ is empty and ui/ does not exist
- 2026-09-11T14:51:18Z by=lead note=CLAUDE.md intro and Running section sit inside the bmad:context managed block; fix through a bmad-project-context refresh, not a hand edit

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

### DW-39: The dark class flip does not reach the 34 OcuPilot-only color roles, only the 30 with a --mat-sys-* counterpart
- source: spec-1-2-the-design-system-tokens-type-and-the-string-table.md | severity: med | fix-risk: med | footprint: in-story
- evidence: Parsed the emitted styles-<hash>.css: the :root.ocu-theme-dark block re-points 30 --mat-sys-* variables and redefines 0 --ocu-* roles. --ocu-shell: #0f3a5f is the only declaration of that name anywhere and nothing under the dark scope changes it, so var(--ocu-shell) is light in both modes. Story 1.10 is named in Design Notes as the first surface drawing shell / on-shell / shell-edge and would have to hand-pick var(--ocu-<role>-dark) per call site, which is not the story's stated 'the flip is a class flip'. The spec's own mechanism sketch shows only --mat-sys-* re-points, so the two readings conflict.
- 2026-09-09T20:39:47Z status=escalated owner=burndown by=cr note=not patched: completing it is a design decision the spec sketch does not show, serving a toggle the spine defers to FR-73; color-scheme half fixed in-story

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

### DW-44: Install re-emits the RoleGranted audit marker on every run, so an idempotent no-op install writes an audit row for a grant that did not happen
- source: spec-1-3-the-installer-creates-ocupilot-s-protected-state-resource-an.md | severity: med | fix-risk: med | footprint: in-story
- evidence: Verified live on ocupilot-iris: %SYS.Audit holds 426 ROLEGRANTED and 415 ROLEGRANTEDPROBE rows for a role granted once, one per Install() call. EnsureGrant has no already-held branch: it calls Security.Users.AddRoles and $System.Security.Audit unconditionally. AD-15 ties the marker to a write; AC10 forces exactly this already/now distinction on the sibling auditing step. But AC9's own text reads 'when install completes ... an audit row is written', which blesses the current behaviour, and AD-46 makes these rows visible in OcuPilot's own audit screen. Whether an idempotent re-install should re-audit is a product call the AC does not settle.
- 2026-09-10T00:30:34Z status=decision-pending owner=burndown by=cr note=Not patched: gating the emission would contradict AC9 as literally worded and would flip TestGrantForRealAccountGrantsAndAudits, whose row-count assertion is the same AC's evidence. Decide once at the epic decision sheet.

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

### DW-49: A private RSA key (the demo X.509 fixture credential) is checked into OcuPilot.Install.Fixture.cls source
- source: spec-1-4-one-command-brings-up-an-instance-with-ocupilot-installed.md | severity: med | fix-risk: high | footprint: in-epic
- evidence: Real secret-scanner-shaped concern (Blind Hunter, 2026-09-10 review). By design per Fixture.cls's own documented rationale: there is no supported ObjectScript API to generate an X.509 certificate at install time, and shelling out to an external tool was rejected as the undocumented-internals risk A…
- 2026-09-10T15:37:03Z status=escalated owner=burndown by=harvest note=harvested at dev_complete; spec severity medium
- 2026-09-11T13:27:48Z occurrence=1-4-one-command-brings-up-an-instance-with-ocupilot-installed
- 2026-09-11T13:27:48Z by=cr note=PKI.CAServer.Configure generates a CA cert+key to files (%ZHSLIB.TLS.Utils uses it); header corrected

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

### DW-60: GateStatus() does a full escalated SQL round trip (New $ROLES / AddRoles / %ExecDirect / %OpenId) on every API request, with no cache once the phase is terminal and no index on Version.Profile
- source: spec-1-4-one-command-brings-up-an-instance-with-ocupilot-installed.md | severity: med | fix-risk: med | footprint: out-of-footprint
- evidence: Installer.GateStatus is called from Api.Router.OnPreDispatch as the first act of every dispatch (AD-38). Harmless today -- no OcuPilot web application exists until Story 1.5 -- but it is on the hot path for every epic after this one, and the phase is terminal once installed.
- 2026-09-11T01:11:19Z status=routed owner=burndown by=cr note=No consumer traffic until 1.5; caching a terminal phase needs an invalidation story, so not a direct correction here.
- 2026-09-11T13:27:48Z occurrence=1-4-one-command-brings-up-an-instance-with-ocupilot-installed

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

### DW-95: Api.StaticHandler writes file bytes to the response device, which AD-12's Rule reserves for the one response writer; the spec grants the carve-out but the spine was never amended
- source: spec-1-5-the-static-shell-serves-the-spa-including-deep-links.md | severity: med | fix-risk: high | footprint: out-of-footprint
- evidence: StaticHandler.StreamToDevice calls pStream.OutputToDevice; AD-12 says the response writer is the only code in the tree permitted to write to the response device. The spec's Boundaries say 'the static handler writes file bytes only', and the Spec Change Log records AD-21/AD-45/AD-13 amended for this story but not AD-12. Only the lead amends the spine (Rule 20).
- 2026-09-12T01:28:23Z status=escalated owner=burndown by=cr note=recommend amending AD-12's Rule to except a stream of static file bytes from a dispatch class that writes no envelope; code needs no change
- 2026-09-12T03:13:51Z status=by-design by=checkin note=owner decided 2026-09-11: AD-12 amended with the static-handler carve-out (file bytes only; every static failure still renders through Error.Render). Code unchanged, spine now matches it

### DW-96: The SQL grant EnsureSqlPrivileges makes is install-created state that neither StateFingerprint nor AnyObjectExists covers, and its schema name is hand-transcribed
- source: spec-1-5-the-static-shell-serves-the-spa-including-deep-links.md | severity: med | fix-risk: high | footprint: out-of-footprint
- evidence: EnsureSqlPrivileges GRANTs OcuPilot_Kernel_State to the DBRESOURCE role on every install; StateFingerprint folds the two applications and the shell role but not the grant, so a revoked or widened grant leaves the fingerprint byte-identical while the install gate answers INSTALL.INSTALLING to every non-%All caller -- the live defect this step was added to fix. tSchema is a literal derived from nothing and pinned by nothing.
- 2026-09-12T01:28:23Z status=escalated owner=burndown by=cr note=fix-risk high: reading a SQL grant inside StateFingerprint's switched-namespace window needs its own failure sentinel; decide the shape at the decision sheet

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

### DW-105: The password-expired branch is unreachable AND its banner is unimplemented: it renders the literal <user> placeholder with no substitution and no links
- source: spec-1-6-silent-first-sign-in.md | severity: med | fix-risk: low | footprint: in-epic
- evidence: epics.md:1194 requires the variant to name the user and link to the classic portal and the README fix; sign-in.ts renders {{ STRINGS.authPasswordExpired }} verbatim and strings.ts:220 carries a literal <user>. The state has no trigger on this build (verified negative, this spec's Verification section).
- 2026-09-12T05:43:27Z status=routed owner=1-13-uniform-error-handling-and-the-connectivity-probe by=cr note=the discriminator half was already routed here in prose; this is the rendering half, unowned until now

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

### DW-119: An identity call that fails in a way that is neither AUTH.NOADMIN nor INSTALL.* leaves the shell on 'checking' with nothing scheduled to ask again, so a signed-in tab can sit on a blank content area
- source: spec-1-8-instance-identity-and-the-api-version-guard.md | severity: med | fix-risk: med | footprint: in-story
- evidence: No retry is scheduled for an unclassified failure; the tab waits until something else moves the session.
- 2026-09-12T09:46:45Z status=open owner=1-8-instance-identity-and-the-api-version-guard by=harvest note=real user-visible dead end; the reviewer may patch it in-pass
- 2026-09-12T10:31:41Z status=routed owner=1-13-uniform-error-handling-and-the-connectivity-probe by=adjudication note=HALF closed: QA pinned that a generic failure settles nothing, so a later verify can still answer. NOT closed: nothing schedules that later verify. 1.13 owns uniform error handling and the connectivity probe, which is where a retry belongs

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

### DW-127: DESIGN.md and EXPERIENCE.md disagree on whether the two blocking notices carry a banner
- source: spec-1-9-the-screen-descriptor-registry-and-privilege-driven-navigati.md | severity: low | fix-risk: low | footprint: out-of-footprint
- evidence: DESIGN.md:1066 against EXPERIENCE.md:348/:428/:429. It touches Story 1.8's shipped instance-notice, not only this story's gated appearance.
- 2026-09-12T12:44:38Z status=escalated owner=burndown by=harvest note=document conflict for the owner; resolving it may change a shipped component

### DW-128: The navigation map is rebuilt from the class dictionary on every accessor call: each descriptor accessor reopens its XData and re-parses the JSON, and Roster calls ScreensForArea once per area
- source: spec-1-9-the-screen-descriptor-registry-and-privilege-driven-navigati.md | severity: med | fix-risk: med | footprint: in-story
- evidence: Measured 2.3 ms at one descriptor, scaling with descriptors x areas. Epic 2 adds descriptors in bulk.
- 2026-09-12T12:44:38Z status=open owner=1-9-the-screen-descriptor-registry-and-privilege-driven-navigati by=harvest note=reviewer may patch; otherwise adjudicate against a later story that adds descriptors in bulk
- 2026-09-12T13:45:10Z status=routed owner=2-3-one-descriptor-declared-read-serves-both-the-screen-and-its by=adjudication note=2.3 is the first story that adds descriptors in bulk, which is where the per-call rebuild (2.3 ms at one descriptor, scaling with descriptors x areas) starts to matter

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

### DW-136: AD-5's Rule still says the write-tool field lists are the only thing generated from a descriptor, while Story 1.9 ships a second generated artifact
- source: spec-1-9-the-screen-descriptor-registry-and-privilege-driven-navigati.md | severity: med | fix-risk: low | footprint: out-of-footprint
- evidence: ARCHITECTURE-SPINE.md AD-5: 'Only one thing is generated from it: the write tools field lists (AD-3)'. ui/tools/screen-mirror.mjs generates ui/src/app/core/screens.generated.ts from the same descriptors. epic-1-context.md authorizes it ('mirrored to the client as generated TypeScript') and AD-5 elsewhere permits resolution 'at build or startup', so the spine sentence is narrower than the epic context - a spine edit is the lead's (Rule 5, Rule 20), the same shape as this story's AD-44 correction.
- 2026-09-12T13:40:06Z status=escalated owner=burndown by=cr note=no implementation change wanted; the mirror serves AD-5's purpose - the sentence needs the lead's one-line sharpening

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

### DW-144: Escape collapses the side bar through toggleOpen(), so a transient dismissal is written to the stored preference and every later area starts collapsed
- source: spec-1-10-header-status-bar-and-page-chrome.md | severity: low | fix-risk: low | footprint: in-story
- evidence: A dismissal and a preference are different intents sharing one writer.
- 2026-09-12T15:34:15Z status=open owner=1-10-header-status-bar-and-page-chrome by=harvest note=two-way door
- 2026-09-12T16:25:18Z status=routed owner=1-12-home by=adjudication note=pinned this pass, not fixed: each needs either copy no planning artifact publishes (DW-126) or a UX call. 1.12 is the first story to render a real screen inside this chrome, where each becomes observable

### DW-145: An unrecognised system mode is drawn verbatim, uncapped and nowrap, so a long value written directly to ^%SYS(SystemMode) would stretch the 24px status bar
- source: spec-1-10-header-status-bar-and-page-chrome.md | severity: low | fix-risk: low | footprint: in-story
- evidence: The setter normalises unknown values to empty, so this needs a direct global write - real but not reachable through the product.
- 2026-09-12T15:34:15Z status=open owner=1-10-header-status-bar-and-page-chrome by=harvest note=two-way door: a max-width and ellipsis
- 2026-09-12T16:25:18Z status=routed owner=1-12-home by=adjudication note=pinned this pass, not fixed: each needs either copy no planning artifact publishes (DW-126) or a UX call. 1.12 is the first story to render a real screen inside this chrome, where each becomes observable

### DW-146: The truncated instance-version segment is recoverable only through a title attribute, which is unreachable by keyboard and unreliable on touch
- source: spec-1-10-header-status-bar-and-page-chrome.md | severity: low | fix-risk: low | footprint: in-story
- evidence: The full version string is available nowhere else in the chrome.
- 2026-09-12T15:34:15Z status=open owner=1-10-header-status-bar-and-page-chrome by=harvest note=
- 2026-09-12T16:25:18Z status=routed owner=1-12-home by=adjudication note=pinned this pass, not fixed: each needs either copy no planning artifact publishes (DW-126) or a UX call. 1.12 is the first story to render a real screen inside this chrome, where each becomes observable

### DW-147: The command bar's view-options control is named by the AC and by DESIGN.md:1037 but is not rendered
- source: spec-1-10-header-status-bar-and-page-chrome.md | severity: low | fix-risk: low | footprint: in-story
- evidence: A doc comment called it out and no deferred entry existed until this pass.
- 2026-09-12T15:34:15Z status=open owner=1-10-header-status-bar-and-page-chrome by=harvest note=scope question for the reviewer: render it or decline it in the spec
- 2026-09-12T16:25:18Z status=routed owner=1-12-home by=adjudication note=pinned this pass, not fixed: each needs either copy no planning artifact publishes (DW-126) or a UX call. 1.12 is the first story to render a real screen inside this chrome, where each becomes observable

### DW-148: Navigations that bypass ShellState.activateArea leave the side bar listing the previous area and never open it: the command box and the locator's area segment both call router.navigateByUrl alone
- source: spec-1-10-header-status-bar-and-page-chrome.md | severity: med | fix-risk: med | footprint: in-epic
- evidence: EXPERIENCE.md:320 says the locator's area segment opens the area's first screen AND its side-bar; locator-bar.ts open() and command-box.ts choose() only navigate. ScreenOutlet's setActiveArea (shell-state.ts:69-74, Story 1.9) never opens the bar and refuses to move visibleArea while it is open, so after a cross-area jump the rail marks the new area while the side bar still lists the old one. Closing it needs ShellState surface that does not exist (show an area's list without activateArea's click-to-collapse).
- 2026-09-12T16:21:05Z status=routed owner=burndown by=cr note=1.10 added the first two affordances that cross areas without activateArea; root cause is 1.9s setActiveArea guard

### DW-149: No Skip to content link, and no ledger entry recorded the gap: the frame now puts banner, rail and side bar ahead of main in Tab order
- source: spec-1-10-header-status-bar-and-page-chrome.md | severity: med | fix-risk: low | footprint: in-epic
- evidence: EXPERIENCE.md:580 Accessibility Floor: 'A Skip to content link is the first Tab stop' (NFR-12, WCAG 2.4.1 Bypass Blocks, Level A). The spec's Boundaries decline it as needing 'a string neither document authorizes', but EXPERIENCE.md:580 publishes the literal on the same line, in the same form, as the 'Breadcrumb' this story did extract - strings.test.mjs's own comment in this diff says so. main already carries tabindex=-1, so only the link and its string are missing.
- 2026-09-12T16:21:17Z status=routed owner=burndown by=cr note=declined in the spec on a reason the loaded UX document contradicts; nothing carried the floor item to the drain until now

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

### DW-157: NavigationService.reload() joins a map read already in flight rather than queueing one, so a scope change inside that window leaves the map computed against the previous namespace
- source: spec-1-11-the-namespace-switch-as-data-scope.md | severity: med | fix-risk: med | footprint: in-story
- evidence: Same single-flight family as DW-4 and DW-102: joining an in-flight read is right for a duplicate request and wrong when the input changed.
- 2026-09-12T18:24:10Z status=open owner=1-11-the-namespace-switch-as-data-scope by=harvest note=third sighting of the join-vs-queue distinction in this epic
- 2026-09-12T19:12:56Z occurrence=1-11-the-namespace-switch-as-data-scope
- 2026-09-12T19:12:56Z status=routed owner=1-14-the-auto-refresh-framework by=cr note=cr upgrades fix-risk to high: app.ts starts both loads in one tick so the window is the cold sign-in path, and the naive queue fix loops via navigation.test.mjs:284; 1.14 owns re-fetch routing

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

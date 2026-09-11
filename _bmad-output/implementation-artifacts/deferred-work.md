# Deferred Work Ledger

See _bmad/custom/skill-rules.md Rule 15 (entry grammar) and Rule 17 (the drain).

### DW-1: Silent probe or form login runs while install is still running
- source: epics-review-findings.json | severity: med | fix-risk: low | footprint: in-story
- evidence: Judge's first load reads as bad credentials rather than install in progress [epics-review edge-case-hunter E1; epics.md:1095-1104 @8981cdf]
- 2026-09-09T15:10:47Z status=routed owner=1-6-silent-first-sign-in by=load note=edge-case-hunter lens, pre-planning route; address in Tasks & Acceptance or decline under Design Notes. guard: AC: a login against a not-yet-installed API renders the 'installing' state, never a sign-in failure

### DW-2: Install fails; readiness reports only installed, version and running
- source: epics-review-findings.json | severity: med | fix-risk: low | footprint: in-story
- evidence: A failed install is indistinguishable from an install that never started [epics-review edge-case-hunter E2; epics.md:1448-1451 @8981cdf]
- 2026-09-09T15:10:47Z status=routed owner=1-17-the-smoke-script-the-readiness-endpoint-and-ci by=load note=edge-case-hunter lens, pre-planning route; address in Tasks & Acceptance or decline under Design Notes. guard: AC: readiness carries a fourth state 'install failed' with the failing step

### DW-3: Container restarts and upgrades OcuPilot while a browser holds the old bundle
- source: epics-review-findings.json | severity: med | fix-risk: low | footprint: in-story
- evidence: Old SPA calls an upgraded API and fails in undefined ways [epics-review edge-case-hunter E4; epics.md:1074-1076 @8981cdf]
- 2026-09-09T15:10:47Z status=routed owner=1-5-the-static-shell-serves-the-spa-including-deep-links by=load note=edge-case-hunter lens, pre-planning route; address in Tasks & Acceptance or decline under Design Notes. guard: AC: the API returns its build stamp; a mismatched client is prompted to reload

### DW-4: Several in-flight calls return 401 at once, each triggering its own refresh
- source: epics-review-findings.json | severity: med | fix-risk: low | footprint: in-story
- evidence: Refresh-token rotation invalidates the pair and signs the user out mid-session [epics-review edge-case-hunter E5; epics.md:1117-1121 @8981cdf]
- 2026-09-09T15:10:47Z status=routed owner=1-6-silent-first-sign-in by=load note=edge-case-hunter lens, pre-planning route; address in Tasks & Acceptance or decline under Design Notes. guard: AC: refresh is single-flight; concurrent 401s await one refresh, then retry

### DW-5: Logout call fails or the instance is unreachable during sign-out
- source: epics-review-findings.json | severity: med | fix-risk: low | footprint: in-story
- evidence: Tokens remain in the tab on a shared machine after apparent sign-out [epics-review edge-case-hunter E6; epics.md:1136-1143 @8981cdf]
- 2026-09-09T15:10:48Z status=routed owner=1-7-sign-out by=load note=edge-case-hunter lens, pre-planning route; address in Tasks & Acceptance or decline under Design Notes. guard: AC: tab storage clears and the form login shows even when logout errors

### DW-6: Tab duplication copies sessionStorage, including token pair and conversation id
- source: epics-review-findings.json | severity: med | fix-risk: low | footprint: in-story
- evidence: Two tabs silently share one token and one conversation lock [epics-review edge-case-hunter E7; epics.md:1111-1115 @8981cdf]
- 2026-09-09T15:10:48Z status=routed owner=1-6-silent-first-sign-in by=load note=edge-case-hunter lens, pre-planning route; address in Tasks & Acceptance or decline under Design Notes. guard: AC: a per-tab nonce is stamped; a duplicated tab re-authenticates and starts a new conversation

### DW-7: User can read a namespace but not write it
- source: epics-review-findings.json | severity: med | fix-risk: low | footprint: in-story
- evidence: Read-only screens become unreachable, contradicting gated-never-hidden [epics-review edge-case-hunter E8; epics.md:1266-1268 @8981cdf]
- 2026-09-09T15:10:48Z status=routed owner=1-11-the-namespace-switch-as-data-scope by=load note=edge-case-hunter lens, pre-planning route; address in Tasks & Acceptance or decline under Design Notes. guard: AC: list every readable namespace; gate its write actions rather than hiding the namespace

### DW-8: Route carries an ns that does not exist or the user cannot enter
- source: epics-review-findings.json | severity: med | fix-risk: low | footprint: in-story
- evidence: Deep link renders an empty or wrongly-scoped screen with no explanation [epics-review edge-case-hunter E9; epics.md:1270-1277 @8981cdf]
- 2026-09-09T15:10:48Z status=routed owner=1-11-the-namespace-switch-as-data-scope by=load note=edge-case-hunter lens, pre-planning route; address in Tasks & Acceptance or decline under Design Notes. guard: AC: an unresolvable ns renders a named error and falls back to a permitted namespace

### DW-9: Roles or classic-page custom resources change after the startup-resolved privilege set
- source: epics-review-findings.json | severity: med | fix-risk: low | footprint: in-story
- evidence: Navigation gating disagrees with the instance until a call fails [epics-review edge-case-hunter E10; epics.md:1192-1201 @8981cdf]
- 2026-09-09T15:10:48Z status=routed owner=1-9-the-screen-descriptor-registry-and-privilege-driven-navigati by=load note=edge-case-hunter lens, pre-planning route; address in Tasks & Acceptance or decline under Design Notes. guard: AC: the privilege map re-reads on any 403 and after a permissions change event

### DW-10: Instance reports no server flag, or one outside the four named
- source: epics-review-findings.json | severity: med | fix-risk: low | footprint: in-story
- evidence: Status bar and Home instance line render an empty badge [epics-review edge-case-hunter E11; epics.md:1237-1239 @8981cdf]
- 2026-09-09T15:10:48Z status=routed owner=1-10-header-status-bar-and-page-chrome by=load note=edge-case-hunter lens, pre-planning route; address in Tasks & Acceptance or decline under Design Notes. guard: AC: an unset or unrecognised flag renders a defined default badge with its word

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

### DW-14: Fixture list omits the suspended task Stories 2.8 and 5.11 require
- source: epics-review-findings.json | severity: med | fix-risk: low | footprint: in-story
- evidence: UJ-6 has no data on a clean install; the Tasks demo cannot run [epics-review edge-case-hunter E15; epics.md:1051-1054 @8981cdf]
- 2026-09-09T15:10:48Z status=routed owner=1-4-one-command-brings-up-an-instance-with-ocupilot-installed by=load note=edge-case-hunter lens, pre-planning route; address in Tasks & Acceptance or decline under Design Notes. guard: AC: Story 1.4's fixture set includes a task suspended after an error

### DW-15: Clean install has no application errors for the Logs area's confirmed write
- source: epics-review-findings.json | severity: med | fix-risk: low | footprint: in-story
- evidence: One-confirmed-write-per-area is unreproducible on the judge's own path [epics-review edge-case-hunter E16; epics.md:1051-1054 @8981cdf]
- 2026-09-09T15:10:48Z status=routed owner=1-4-one-command-brings-up-an-instance-with-ocupilot-installed by=load note=edge-case-hunter lens, pre-planning route; address in Tasks & Acceptance or decline under Design Notes. guard: AC: the demo opt-in seeds application errors, or the Logs demo names another write

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

### DW-24: Kernel.Utils.ReadRequestBody's inner fallback Catch (around %request.Content) silently reports a genuine read fault as an empty, successful body inst…
- source: spec-1-1-the-workspace-the-pinned-stack-and-one-response-envelope.md | severity: med | fix-risk: low | footprint: in-epic
- evidence: Traced directly: the inner Catch sets tStream='' and execution falls through to 'If '$IsObject($Get(tStream)) Quit', exiting with tSC still $$$OK. Real defect, but Kernel.Utils has zero consumers and zero test coverage in this story (see the companion deferred entry), so fixing this one path withou…
- 2026-09-09T17:18:06Z status=routed owner=1-6-silent-first-sign-in by=harvest note=harvested from build-auto deferred: at dev_complete; spec severity medium

### DW-25: OcuPilot.Api.Router.ReportHttpStatusCode's new $$$ISERR(pSC) branch (rendering an internal-error envelope when %CSP.REST itself passes a failing stat…
- source: spec-1-1-the-workspace-the-pinned-stack-and-one-response-envelope.md | severity: med | fix-risk: low | footprint: in-epic
- evidence: Verified via irislib/%CSP/REST.cls:351-421: OnPreDispatch's own error status is re-thrown by $$$ThrowOnError and caught by DispatchRequest's outer Try/Catch, which is the one call site that ever passes a genuine error pSC into ReportHttpStatusCode. No fixture route or test in this story forces OnPr…
- 2026-09-09T17:18:06Z status=routed owner=1-5-the-static-shell-serves-the-spa-including-deep-links by=harvest note=harvested from build-auto deferred: at dev_complete; spec severity medium

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

### DW-32: The structural XData UrlMap route-ordering check the spec's Design Notes promise does not exist in check-objectscript.py
- source: spec-1-1-the-workspace-the-pinned-stack-and-one-response-envelope.md | severity: med | fix-risk: med | footprint: in-epic
- evidence: Design Notes: 'the three invariants are enforced by a structural check over the router's XData UrlMap ... the structural check is what catches the first real violation in Story 1.5.' check-objectscript.py has exactly four checks (rename tokens, naming, write discipline, package placement); none parses UrlMap. The production Api/Router.cls UrlMap is empty, so the behavioural fixture tests cannot catch a violation in it either.
- 2026-09-09T17:56:23Z status=routed owner=1-5-the-static-shell-serves-the-spa-including-deep-links by=cr note=1.5 adds the first real routes; the promised gate must exist before they land or the invariants are unenforced
- 2026-09-09T18:00:07Z status=escalated owner=burndown by=cr note=fix-risk raised to high: correctness cannot be demonstrated in this story, the production UrlMap is empty so there is no route to validate a new checker rule against

### DW-33: OnPreDispatch validates the resolved namespace and discards it, though the spec's Task item and Design Notes both say it stashes the result
- source: spec-1-1-the-workspace-the-pinned-stack-and-one-response-envelope.md | severity: med | fix-risk: low | footprint: in-epic
- evidence: Api/Router.cls:84-89 - tNs is used only for the %SYS.Namespace.Exists() test and goes out of scope. Nothing stashes it. The code itself is correct for this story (resolve once, validate, deny), but Design Notes name Story 1.11 as building namespace-as-data-scope on 'OnPreDispatch's single resolution point', which currently produces no consumable result.
- 2026-09-09T17:56:23Z status=routed owner=1-11-the-namespace-switch-as-data-scope by=cr note=1.11 must add the stash and its first consumer together; adding undemonstrated process-wide state now was rejected at review

### DW-34: Api.Router.ReportHttpStatusCode's Else branch and Api.Error.GetSlugForStatus ship reachable but untested, and emit a numeric machine code the Design Notes rule out
- source: spec-1-1-the-workspace-the-pinned-stack-and-one-response-envelope.md | severity: med | fix-risk: low | footprint: in-epic
- evidence: Reachable, not theoretical: %CSP.REST.Page() at irislib/%CSP/REST.cls:169 calls ..Http403() on a security-application failure, which reaches this override with pSC=$$$OK and takes the Else branch. That branch emits code "ROUTE." _ tStatus (ROUTE.403), while the spec's Design Notes settle code as 'a stable dotted uppercase identifier ... rather than a number'. GetSlugForStatus's twelve-way mapping is called only from this branch and has no test; inverting any pair leaves all 28 tests green.
- 2026-09-09T17:56:40Z status=routed owner=1-5-the-static-shell-serves-the-spa-including-deep-links by=cr note=1.5 is the first story with a live web app where Page() runs; fix the code format and add direct GetSlugForStatus assertions there
- 2026-09-09T18:04:10Z status=routed owner=1-5-the-static-shell-serves-the-spa-including-deep-links by=adjudication note=numeric-code half fixed in-story (code now ROUTE.<SLUG>) with a demonstrated mutation; residual is the Else branch having no dispatch-level test. This update was mis-appended to DW-35 at review.

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

### DW-37: Two I/O & Edge-Case Matrix rows -- 'Non-role color literals are quarantined' and 'Scale and metrics' -- have real, passing pinning tests but no corre…
- source: spec-1-2-the-design-system-tokens-type-and-the-string-table.md | severity: low | fix-risk: low | footprint: in-story
- evidence: The Mutations list under `## Verification` predates this implementation (unchanged by this diff) and never covered either row. Both rows are still covered by a real, passing test (design-tokens.test.mjs's non-role-literal tests; typography.test.mjs's scale/radii/heights/metrics tests), so the Matri…
- 2026-09-09T20:02:03Z status=open owner=1-2-the-design-system-tokens-type-and-the-string-table by=harvest note=harvested at dev_complete; Rule 19 gap - passing tests exist but no mutation: line records their falsifiability
- 2026-09-09T20:42:50Z status=resolved-by:1-2-the-design-system-tokens-type-and-the-string-table by=adjudication note=QA demonstrated both missing mutations (logo-gradient-stop moved into COLOR_ROLES; radius-md 6px->8px) and the code review independently re-applied both and confirmed red with the logged messages. All 17 matrix rows now carry a mutation line.

### DW-38: The vendored OFL licence texts do not travel with the woff2 faces into the redistributed bundle
- source: spec-1-2-the-design-system-tokens-type-and-the-string-table.md | severity: med | fix-risk: low | footprint: in-epic
- evidence: angular.json's assets is [] and only url()-referenced files are copied, so dist/ocupilot-ui/browser/media/ holds the five hashed woff2 and no licence text (verified after a real build). dist/ocupilot-ui/3rdpartylicenses.txt is esbuild's npm extract, one directory above the served root, and does not name Inter or JetBrains Mono. SIL OFL 1.1 section 2 requires the notice to accompany each distributed copy of the Font Software; near-universal web practice ships webfonts without a co-located licence, so whether the source-tree copy suffices is a call, not a defect. The story's Task list also says angular.json needs only the styles edit.
- 2026-09-09T20:39:36Z status=decision-pending owner=burndown by=cr note=legal/packaging call for the decision sheet; candidate homes are angular.json assets, an ATTRIBUTIONS file, or the IPM module (1.16)

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

### DW-46: OcuPilot.Test.Demo TestDemoTaskIsSuspendedAfterAnError is flaky on this specific long-lived ocupilot container (Task Manager daemon latency growing w…
- source: spec-1-4-one-command-brings-up-an-instance-with-ocupilot-installed.md | severity: med | fix-risk: med | footprint: in-story
- evidence: Verified live, repeatedly, in review: OcuPilot.Install.Fixture's demo task fixture (RunNow + poll for Suspended>0) is functionally correct -- a standalone classmethod call (bypassing %UnitTest) reached Suspended=1 in ~50s on one attempt and ~150s on another, both same-session -- but OcuPilot.Test.D…
- 2026-09-10T15:37:03Z status=open owner=1-4-one-command-brings-up-an-instance-with-ocupilot-installed by=harvest note=harvested at dev_complete; spec severity med
- 2026-09-10T16:01:33Z status=open owner=1-4-one-command-brings-up-an-instance-with-ocupilot-installed by=adjudication note=ROOT CAUSE FOUND and it is not daemon latency. %SYS.TaskSuper.QueryTasks populates its output array at subscript 0, and ObjectScript evaluates 0 '= "" as FALSE (the empty string numifies to 0). Install/Fixture.cls guards its QueryTasks iterations with '= "" in at least two places (line 258 CreateTask id extraction, lines 457-458 the Remove delete loop), so the demo task is never found and never deleted while Remove still returns OK. Confirmed live: Remove('probe') returned 1 and left task 1022 on the instance. Report loops are safe - Report() uses $Increment, which starts at 1.
- 2026-09-10T17:24:51Z status=resolved-by:1-4-one-command-brings-up-an-instance-with-ocupilot-installed by=adjudication note=CORRECTION - the subscript-0 mechanism I attached to this entry is disproven (see DW-53). Test.Demo's redness had two real sources, neither of them that: (1) RemoveOne's discarded %DeleteId status leaving stale tasks, now fixed; (2) iris_execute_tests re-submitting on client timeout, producing ~5 concurrent server-side runs racing on the same name-keyed %SYS.Task row - filed separately.
- 2026-09-11T04:02:03Z status=open owner=1-4-one-command-brings-up-an-instance-with-ocupilot-installed by=adjudication note=DIAGNOSIS CORRECTED AGAIN, by the lead, from run 304 read out of %UnitTest_Result. The red method is TestDemoSeedsAnApplicationError, NOT TestDemoTaskIsSuspendedAfterAnError - the latter PASSED after waiting 180s, so the daemon is alive and did run the task. The red one fails in 17ms on two assertions: no error-log entry since this run's floor, and no inventory row. Cause: Fixture.CreateErrorEntry runs inside Create() and confirms an entry that only exists AFTER the daemon has run the demo task, which in this same run took 180s. The fixture's confirmation races the daemon by design. Not 'daemon dead' (it serviced scheduled tasks today, $H day 67824) and not a narrow 59s granularity window.
- 2026-09-11T07:35:33Z status=open owner=1-4-one-command-brings-up-an-instance-with-ocupilot-installed by=adjudication note=CORRECTION TO MY OWN 04:02 TRAILER, per the owner's hand-off (2026-09-11, _bmad-output/party-mode/handoff-story-1-4-task-fixture-2026-09-11.md). I wrote that TestDemoTaskIsSuspendedAfterAnError 'PASSED after waiting 180s, so the daemon is alive and did run the task'. That inference was invalid: the pass was the SKIP branch, reached because the grace loop re-opened the task with %OpenId while still holding the previous OREF, and %Library.Persistent.%Open returns the in-memory OREF without reloading unless concurrency is upgraded past 2 (irislib line 727). The test has never observed a suspended task; every pass was the skip. Run 314 proves it: task 1047 was suspended by the daemon at 07:13 while the test polled until 07:15 and skipped. Real causes: (1) both wait loops poll a frozen object; (2) inference, to verify - the fixture holds the task OREF across RunNow and its whole wait, blocking the daemon, which is why 13 of 13 fixture tasks ran at Create+6min, one poll after the 5-min wait ended. The '50s->150s->240s+ latency' seen in earlier rounds was the fixture's own wait plus one poll.

### DW-47: OcuPilot.Kernel.State.Version has no unique constraint on Profile, so two overlapping Install()/StartPath() calls for the same profile could create t…
- source: spec-1-4-one-command-brings-up-an-instance-with-ocupilot-installed.md | severity: med | fix-risk: low | footprint: in-story
- evidence: Verified by code read (2026-09-10 review): EnsureVersion does a read-then- insert-or-update with no transaction and no unique index on Profile; two concurrent Install() calls for the same profile could both read 'no row' and both insert, leaving two rows GuardedCurrentForProfile's TOP-1-ORDER-BY-ID…
- 2026-09-10T15:37:03Z status=open owner=1-4-one-command-brings-up-an-instance-with-ocupilot-installed by=harvest note=harvested at dev_complete; spec severity medium

### DW-48: The container start hook compiles the entire src/OcuPilot/ tree, including every Test.* fixture/fault-injection class, into the production instance
- source: spec-1-4-one-command-brings-up-an-instance-with-ocupilot-installed.md | severity: med | fix-risk: med | footprint: in-story
- evidence: Real, and this story is what makes 'compile the whole source tree on every container start' the actual shipped mechanism (previously loaded ad hoc via MCP tools). Explicitly directed by this spec's own Code Map/Design Notes ('the start hook loads and compiles the src/OcuPilot/ tree ... no roster fi…
- 2026-09-10T15:37:03Z status=open owner=1-4-one-command-brings-up-an-instance-with-ocupilot-installed by=harvest note=harvested at dev_complete; spec severity medium
- 2026-09-10T21:44:22Z status=escalated owner=burndown by=cr note=fix-risk high: exclusion needs a roster AD-17 forbids or a tree move that changes FIXED_PACKAGES and 1.16 module.xml input; decision sheet

### DW-49: A private RSA key (the demo X.509 fixture credential) is checked into OcuPilot.Install.Fixture.cls source
- source: spec-1-4-one-command-brings-up-an-instance-with-ocupilot-installed.md | severity: med | fix-risk: high | footprint: in-epic
- evidence: Real secret-scanner-shaped concern (Blind Hunter, 2026-09-10 review). By design per Fixture.cls's own documented rationale: there is no supported ObjectScript API to generate an X.509 certificate at install time, and shelling out to an external tool was rejected as the undocumented-internals risk A…
- 2026-09-10T15:37:03Z status=escalated owner=burndown by=harvest note=harvested at dev_complete; spec severity medium

### DW-50: AC1-AC3/AC9-AC12's container, health-check, HTTP, and shell-level (demo-flag propagation) surfaces are verified only by a one-off manual throwaway-co…
- source: spec-1-4-one-command-brings-up-an-instance-with-ocupilot-installed.md | severity: med | fix-risk: med | footprint: in-epic
- evidence: Three reviewers converged on the same root cause from different angles (2026-09-10 review): verification-gap found StartPath(1)'s production-profile demo-fixture branch (the exact call docker-compose.yml's own OCUPILOT_DEMO=1 wires up) has zero %UnitTest coverage; the intent-alignment auditor separ…
- 2026-09-10T15:37:03Z status=routed owner=1-17-the-smoke-script-the-readiness-endpoint-and-ci by=harvest note=harvested at dev_complete; spec severity medium
- 2026-09-10T21:44:22Z occurrence=1-4-one-command-brings-up-an-instance-with-ocupilot-installed
- 2026-09-10T21:44:22Z status=routed owner=1-17-the-smoke-script-the-readiness-endpoint-and-ci by=cr note=routing honest for container/HTTP/shell; AC9 sslconfig+x509+webapp props need no container and stay in 1.4

### DW-51: ReportGatewayGap's Web Gateway timeout reader matches 'Server_Response_Timeout' as an unanchored substring, so a comment or unrelated CSP.ini line co…
- source: spec-1-4-one-command-brings-up-an-instance-with-ocupilot-installed.md | severity: low | fix-risk: low | footprint: in-story
- evidence: Real (Edge Case Hunter, 2026-09-10 review) but low-impact: the value is reported as information only and never modifies anything (AD-17/AD-27). Anchoring the match correctly needs this build's actual CSP.ini comment conventions, not verified in the time available for this review. [loc: ]
- 2026-09-10T15:37:03Z status=open owner=1-4-one-command-brings-up-an-instance-with-ocupilot-installed by=harvest note=harvested at dev_complete; spec severity low

### DW-52: A narrow race in Fixture.CreateTask: the demo task's id could be deleted between QueryTasks and the following %OpenId, misreporting as 'not yet suspe…
- source: spec-1-4-one-command-brings-up-an-instance-with-ocupilot-installed.md | severity: low | fix-risk: low | footprint: in-story
- evidence: Real (Edge Case Hunter, 2026-09-10 review) but narrow and low-probability -- requires something else to delete the fixture's own task between two back-to-back reads in the same method. Deferred rather than rushed. [loc: ]
- 2026-09-10T15:37:03Z status=open owner=1-4-one-command-brings-up-an-instance-with-ocupilot-installed by=harvest note=harvested at dev_complete; spec severity low

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

### DW-57: Fixture.RemoveOne's three status-checked Delete branches (webapp/sslconfig/x509credential, H3/M4) are exercised only on their success paths -- no com…
- source: spec-1-4-one-command-brings-up-an-instance-with-ocupilot-installed.md | severity: low | fix-risk: low | footprint: in-story
- evidence: Verification Gap (2026-09-10 review, iteration 3 pass): real gap, but lower priority than the two high-severity untested-regression gaps this same pass closed (H1's Uninstall-ordering test, M1's failed-first-install test) -- deferred rather than expanding this pass further. A failure-injection test…
- 2026-09-11T00:43:50Z status=open owner=1-4-one-command-brings-up-an-instance-with-ocupilot-installed by=harvest note=harvested at dev_complete rework iteration 3
- 2026-09-11T01:11:09Z occurrence=1-4-one-command-brings-up-an-instance-with-ocupilot-installed

### DW-58: Test/Demo.cls's date-scoped SYS.ApplicationError:ErrorList queries (TestDemoSeedsAnApplicationError and Fixture.CreateErrorEntry alike) can miss a re…
- source: spec-1-4-one-command-brings-up-an-instance-with-ocupilot-installed.md | severity: low | fix-risk: low | footprint: in-story
- evidence: Observed live (build-auto, 2026-09-10/11 review, iteration 3 pass): a full OcuPilot.Test.Demo class run failed TestDemoSeedsAnApplicationError with both of its ^ERRORS-derived assertions red, immediately after this session's own work crossed midnight (compile timestamps moved from 09/10 to 09/11) -…
- 2026-09-11T00:43:50Z status=open owner=1-4-one-command-brings-up-an-instance-with-ocupilot-installed by=harvest note=harvested at dev_complete rework iteration 3
- 2026-09-11T01:11:09Z occurrence=1-4-one-command-brings-up-an-instance-with-ocupilot-installed
- 2026-09-11T01:11:09Z by=cr note=same root cause found in the false-green direction; cr round 2 MED closes it by scoping the query to this run

### DW-59: The demo X.509 fixture bypasses %SYS.X509Credentials' own LoadCertificate path, so the credential lands with empty SubjectDN/IssuerDN/Thumbprint/SerialNumber/validity metadata and HasPrivateKey=0
- source: spec-1-4-one-command-brings-up-an-instance-with-ocupilot-installed.md | severity: med | fix-risk: high | footprint: in-story
- evidence: Fixture.CreateX509Credential sets Certificate and the [Transient] PrivateKey directly; irissys/%SYS/X509Credentials.cls documents SubjectKeyIdentifier, Thumbprint, SerialNumber, IssuerDN, SubjectDN and the validity dates as set only via LoadCertificate, with [Internal,Private] setters, and only LoadPrivateKey sets HasPrivateKey. AC9's observable (alias exists) holds; Story 6.3's non-empty Security lists would show a mostly-empty row. Needs a verified supported path from a checked-in PEM pair into those fields -- LoadCertificate reads a filesystem path, which AD-21 constrains -- so research, not a correction.
- 2026-09-11T01:11:19Z status=escalated owner=burndown by=cr note=Rule 15: MED with fix-risk high -> decision sheet. Same fixture as DW-49; decide together.

### DW-60: GateStatus() does a full escalated SQL round trip (New $ROLES / AddRoles / %ExecDirect / %OpenId) on every API request, with no cache once the phase is terminal and no index on Version.Profile
- source: spec-1-4-one-command-brings-up-an-instance-with-ocupilot-installed.md | severity: med | fix-risk: med | footprint: out-of-footprint
- evidence: Installer.GateStatus is called from Api.Router.OnPreDispatch as the first act of every dispatch (AD-38). Harmless today -- no OcuPilot web application exists until Story 1.5 -- but it is on the hot path for every epic after this one, and the phase is terminal once installed.
- 2026-09-11T01:11:19Z status=routed owner=burndown by=cr note=No consumer traffic until 1.5; caching a terminal phase needs an invalidation story, so not a direct correction here.

### DW-61: The AC12/DW-58 fix's own tSinceSecsFloor (Fixture.CreateErrorEntry, and the independent copy in Test/Demo.cls TestDemoSeedsAnApplicationError) floors…
- source: spec-1-4-one-command-brings-up-an-instance-with-ocupilot-installed.md | severity: med | fix-risk: low | footprint: in-story
- evidence: Verified by code read (build-auto step-04 review pass, 2026-09-11; cited independently by Blind Hunter, Edge Case Hunter and Verification Gap in the same review): tSinceSecsFloor = (tSinceSecs \ 60) * 60 rounds DOWN to the start of pSinceH's own minute, so any entry timestamped at or after that min…
- 2026-09-11T04:00:26Z status=open owner=1-4-one-command-brings-up-an-instance-with-ocupilot-installed by=harvest note=harvested at dev_complete rework iteration 4
- 2026-09-11T04:02:03Z status=open owner=1-4-one-command-brings-up-an-instance-with-ocupilot-installed by=adjudication note=understated. This is not only a ~59s granularity window - as shipped, TestDemoSeedsAnApplicationError fails deterministically because CreateErrorEntry confirms at Create() time an entry the daemon has not produced yet. See DW-46's corrected diagnosis.
- 2026-09-11T07:35:33Z status=open owner=1-4-one-command-brings-up-an-instance-with-ocupilot-installed by=adjudication note=CORRECTION TO MY OWN 04:02 TRAILER. I attributed TestDemoSeedsAnApplicationError's red to CreateErrorEntry confirming at Create() time an entry the daemon had not produced. Superseded: rework iteration 5 moved the seed to a deterministic $$LOG^%ETN() entry that does not depend on the daemon, and it is green in run 314 (1.7s; HSCUSTOM error #15 at 07:07:16 reads <DIVIDE>SeedApplicationError+7^OcuPilot.Install.Fixture.1). AC12 is done. My mechanism may have been right for the old code, but I asserted it off an unverified premise - see DW-46.

### DW-62: TestExistingApplicationIsNeverModified's new call to OcuPilot.Test.DemoAppProbe.Create('probe', ...) (this pass's own HIGH-finding fix) re-runs Fixtu…
- source: spec-1-4-one-command-brings-up-an-instance-with-ocupilot-installed.md | severity: med | fix-risk: low | footprint: in-story
- evidence: Verified by code read (build-auto step-04 review pass, 2026-09-11; cited independently by Blind Hunter, Edge Case Hunter and Verification Gap): Fixture.CreateTask's existing-task branch checks +tTask.Suspended > 0 and, if still 0, calls RunNow and waits up to TASKWAITSECONDS (300s) again, unconditi…
- 2026-09-11T04:00:26Z status=open owner=1-4-one-command-brings-up-an-instance-with-ocupilot-installed by=harvest note=harvested at dev_complete rework iteration 4

### DW-63: Installer.IsEscalationInfrastructureAbsent -- this pass's own step-03 verify-stage fix for a real, live-discovered AC2 first-install ordering defect …
- source: spec-1-4-one-command-brings-up-an-instance-with-ocupilot-installed.md | severity: med | fix-risk: low | footprint: in-story
- evidence: Verified by code read and grep (build-auto step-04 review pass, 2026-09-11; cited independently by Verification Gap and the Intent Alignment Auditor): grep for IsEscalationInfrastructureAbsent across the tree finds it only in Installer.cls itself and this spec's own narrative -- no .cls test refere…
- 2026-09-11T04:00:26Z status=open owner=1-4-one-command-brings-up-an-instance-with-ocupilot-installed by=harvest note=harvested at dev_complete rework iteration 4

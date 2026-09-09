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

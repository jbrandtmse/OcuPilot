/// <p>The single HTTP entry point for the OcuPilot REST API. Stateless (no CSP session),
/// JSON-first.</p>
/// <p>This story ships no application route — the <code>UrlMap</code> below is empty.
/// Story 1.5 creates the two web applications and adds the first real routes; the three
/// ordering invariants below are load-bearing from that point on and are each asserted by
/// their own routing test in <class>OcuPilot.Test.Routing</class> against
/// <class>OcuPilot.Test.RouterFixture</class>, which inherits this class's real
/// <method>OnPreDispatch</method>, <method>ReportHttpStatusCode</method> and
/// <method>Http405</method> unchanged.</p>
Class OcuPilot.Api.Router Extends %CSP.REST
{

/// <p>Stateless REST: no CSP session per request.</p>
Parameter UseSession = 0;

/// <p>Every OcuPilot response is JSON.</p>
Parameter CONTENTTYPE = "application/json";

/// <p><code>%CSP.REST</code> tries routes in file order and dispatches to the first one
/// whose URL pattern and HTTP method both match (<code>%Regex.Matcher.Match</code> requires
/// a <b>full</b> match, but a trailing <code>:param</code> segment's capture group is not
/// restricted from spanning an embedded <code>/</code> — so a shorter pattern ending in a
/// wildcard can fully match a longer URL unless a more specific route is listed first).
/// Three ordering invariants therefore apply to every route added to this map
/// (Consistency Conventions: REST route ordering), each demonstrated behaviourally against
/// <class>OcuPilot.Test.RouterFixture</class>'s own routes:</p>
/// <ol>
/// <li>Explicit method-guard (405) routes before the catch-all for the same path.</li>
/// <li>Sub-resource routes before single-segment <code>:param</code> routes.</li>
/// <li>N-segment routes before (N-1)-segment routes.</li>
/// </ol>
/// <p><code>Call=</code> targets are thin wrappers with no business logic — dispatch to a
/// slice's own handler class.</p>
XData UrlMap [ XMLNamespace = "http://www.intersystems.com/urlmap" ]
{
<Routes>
</Routes>
}

/// <p>Resolves the authenticated caller for this request. Returns <code>$Username</code> —
/// the identity the CSP/web-application login has already established by the time
/// dispatch begins — by default.</p>
/// <p>Overridable so <class>OcuPilot.Test.RouterFixture</class> can inject a fixture
/// identity for <method>OnPreDispatch</method>'s pre-dispatch-denial tests without a real
/// authenticated HTTP session; production code never overrides this.</p>
ClassMethod ResolvedUsername() As %String
{
    Quit $Username
}

/// <p>Runs once per request, before any route is dispatched (AD-16's single resolution
/// point). Two concerns, each resolved exactly once:</p>
/// <ol>
/// <li><b>Caller identity.</b> Rejects the unauthenticated placeholders
/// <code>UnknownUser</code> and <code>_PUBLIC</code> explicitly (AD-21) — anonymous does
/// not mean unprivileged, so this never infers authorization from <code>$Roles</code>
/// alone.</li>
/// <li><b>Namespace.</b> The <code>?ns=</code> query parameter, defaulting to the
/// namespace already in effect when the request begins (the web application's configured,
/// installed namespace) and validated with <code>##class(%SYS.Namespace).Exists()</code> —
/// the value is never concatenated into anything.</li>
/// </ol>
/// <p>Both checks only read state; neither reaches <code>%SYS</code> or any other
/// namespace, so this method never switches <code>$NAMESPACE</code> and there is nothing
/// to restore on the error path. A future story whose resolution needs a
/// <code>%SYS</code>-only call must bracket it with
/// <class>OcuPilot.Kernel.Utils</class>'s <method>SwitchNamespace</method> /
/// <method>RestoreNamespace</method> pair, restoring first in its <code>Catch</code>
/// (AD-16) — the pair is harvested and ready for exactly that.</p>
/// <p>A denial never <code>Write</code>s directly: it sets <var>pContinue</var> to 0 and
/// renders through <class>OcuPilot.Api.Error</class>, the tree's one error writer.</p>
ClassMethod OnPreDispatch(pUrl As %String, pMethod As %String, ByRef pContinue As %Boolean) As %Status
{
    Set tSC = $$$OK
    Set pContinue = 1
    Try {
        Set tUser = ..ResolvedUsername()
        If (tUser = "") || (tUser = "UnknownUser") || (tUser = "_PUBLIC") {
            Set pContinue = 0
            Do ##class(OcuPilot.Api.Error).Render(401, ##class(OcuPilot.Api.Error).#UNAUTHORIZED, "Authentication required", "AUTH.ANONYMOUS")
            Quit
        }

        Set tNs = %request.Get("ns", $Namespace)
        If (tNs '= $Namespace) && ('##class(%SYS.Namespace).Exists(tNs)) {
            Set pContinue = 0
            Do ##class(OcuPilot.Api.Error).Render(400, ##class(OcuPilot.Api.Error).#BADREQUEST, "Unknown namespace", "NS.UNKNOWN")
            Quit
        }
    } Catch ex {
        Set pContinue = 0
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Framework-error override: renders every status this class did not otherwise handle
/// through <class>OcuPilot.Api.Error</class> instead of the superclass's own
/// <code>{status, ...}</code> shape. <code>%CSP.REST.DispatchRequest</code> calls this with
/// <code>HTTP404NOTFOUND</code> when no route matches at all.</p>
ClassMethod ReportHttpStatusCode(pHttpStatus, pSC As %Status = {$$$OK}) As %Status
{
    Set tStatus = +pHttpStatus
    If $$$ISERR(pSC) {
        Do ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(pSC))
    } ElseIf tStatus = 404 {
        Do ##class(OcuPilot.Api.Error).Render(404, ##class(OcuPilot.Api.Error).#NOTFOUND, "The requested route does not exist", "ROUTE.NOTFOUND")
    } Else {
        Do ##class(OcuPilot.Api.Error).Render(tStatus, ##class(OcuPilot.Api.Error).GetSlugForStatus(tStatus), "Request failed", "ROUTE." _ tStatus)
    }
    Quit $$$OK
}

/// <p>Framework-error override for a mapped route with no matching verb.
/// <code>DispatchRequest</code> calls this with the comma-separated list of verbs that
/// <b>are</b> supported at the matched path; delegates to
/// <method>OcuPilot.Api.Error.Render405</method>, which sets the <code>Allow</code>
/// header.</p>
ClassMethod Http405(pSupportedVerbs As %String = "") As %Status
{
    Do ##class(OcuPilot.Api.Error).Render405(pSupportedVerbs)
    Quit $$$OK
}

}

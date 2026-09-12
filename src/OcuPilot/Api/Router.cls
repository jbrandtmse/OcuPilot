/// <p>The single HTTP entry point for the OcuPilot REST API. Stateless (no CSP session),
/// JSON-first.</p>
/// <p>The <code>UrlMap</code> below is still empty: Story 1.5 created the
/// <code>/api/ocupilot</code> web application that dispatches here, so this class now
/// answers real HTTP, but the route table itself is Story 1.9's descriptor registry. Until
/// then every request that clears <method>OnPreDispatch</method> is answered by the
/// framework 404 override. The three
/// ordering invariants below are load-bearing from the first route on and are each asserted by
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

/// <p>CORS processing is off unconditionally (AD-47). Left unspecified — the inherited
/// <code>%CSP.REST</code> default — the decision is delegated to a route's own
/// <code>Cors</code> attribute, so "no CORS allowance exists" would be a property of the
/// route table rather than of this class. <code>0</code> is the falsifiable form: no route
/// added later can opt back in without changing this line.</p>
/// <p>Same-origin is the design in development as well as production: the dev loop proxies
/// through the IRIS origin (<file>ui/proxy.conf.json</file>), so no allowance has to exist
/// for <code>ng serve</code> either.</p>
Parameter HandleCorsRequest = 0;

/// <p>The closed list of IRIS administrative resources <method>HoldsAdminResource</method>
/// tests, comma-separated. Holding <b>any one</b> of them at <code>USE</code> is what the
/// FR-65 gate requires of a caller; holding none of them is a 403, whatever else the caller
/// holds.</p>
/// <p>Read from the instance on 2026-09-11 (<code>Security.Resources:List</code> over
/// <code>%Admin*</code>) -- all thirteen it defines. A closed list, not a wildcard scan:
/// what OcuPilot admits must not silently widen because a later IRIS release adds a
/// resource, and a list is what a reviewer can check.</p>
Parameter ADMINRESOURCES = "%Admin_ExternalLanguageServerEdit,%Admin_FileSystemAccess,%Admin_Journal,%Admin_Manage,%Admin_OAuth2_Client,%Admin_OAuth2_Registration,%Admin_OAuth2_Server,%Admin_Operate,%Admin_RoleEdit,%Admin_Secure,%Admin_Task,%Admin_UserEdit,%Admin_Wallet";

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

/// <p>Resolves the install gate's current status: <code>installed</code> when traffic
/// may proceed, otherwise <code>installing</code>, <code>failed</code> or
/// <code>upgraderequired</code> (AD-38). Delegates to
/// <class>OcuPilot.Install.Installer</class>, which owns the version-stamp read and its
/// fail-open-to-"installing" discipline.</p>
/// <p>Overridable so <class>OcuPilot.Test.GateFixture</class> can force each phase
/// through a fixture query parameter without weakening this real dispatch path or the
/// real installer read; production code never overrides this.</p>
ClassMethod GateStatus() As %String
{
    Quit ##class(OcuPilot.Install.Installer).GateStatus()
}

/// <p>Whether the calling process holds at least one of
/// <parameter>ADMINRESOURCES</parameter> at <code>USE</code>, evaluated in that process at
/// the moment of the call and never cached (AD-8). <code>$System.Security.Check</code> is a
/// <code>%SYSTEM</code> call and needs no namespace switch.</p>
/// <p>The list it reads is what <class>OcuPilot.Test.Wire</class> checks against the
/// instance's own resource set, so a name that no longer exists cannot sit in it unnoticed.</p>
ClassMethod HoldsAdminResource() As %Boolean
{
    Set tHolds = 0
    Set tList = ..#ADMINRESOURCES
    For tI = 1:1:$Length(tList, ",") {
        Set tResource = $Piece(tList, ",", tI)
        If (tResource '= "") && ($System.Security.Check(tResource, "USE")) {
            Set tHolds = 1
            Quit
        }
    }
    Quit tHolds
}

/// <p>Runs once per request, before any route is dispatched (AD-16's single resolution
/// point). Four concerns, each resolved exactly once, the install gate <b>first</b> and
/// <b>before authentication</b> (AD-38 — a request must not learn anything about the
/// instance, not even whether the caller is who they say, while install has not
/// finished):</p>
/// <ol>
/// <li><b>Install gate.</b> <method>GateStatus</method> resolves to <code>installed</code>
/// only when the version stamp's phase is <code>installed</code> <i>and</i> its stored
/// schema version equals the deployed one; any other value refuses with a single 503
/// envelope naming the matching <code>INSTALL.*</code> code (AC7).</li>
/// <li><b>Caller identity.</b> Rejects the unauthenticated placeholders
/// <code>UnknownUser</code> and <code>_PUBLIC</code> explicitly (AD-21) — anonymous does
/// not mean unprivileged, so this never infers authorization from <code>$Roles</code>
/// alone.</li>
/// <li><b>Administrative privilege (FR-65).</b> The caller must hold at least one
/// <code>%Admin_*</code> resource at <code>USE</code>
/// (<method>HoldsAdminResource</method>, against the closed
/// <parameter>ADMINRESOURCES</parameter> list); otherwise 403 with the machine code
/// <code>AUTH.NOADMIN</code>. <b>A caller who lacks read on the install namespace's
/// database never reaches this method at all</b> — IRIS cannot load this class for that
/// request, and the framework answers a bare 403 with no envelope, which is why README.md
/// states the read requirement rather than leaving it to be discovered from a
/// response.</li>
/// <li><b>Namespace.</b> The <code>?ns=</code> query parameter, defaulting to the
/// namespace already in effect when the request begins (the web application's configured,
/// installed namespace) and validated with <code>##class(%SYS.Namespace).Exists()</code> —
/// the value is never concatenated into anything.</li>
/// </ol>
/// <p>None of the four reaches <code>%SYS</code> or any other namespace from here — the
/// gate's own namespace switching lives entirely inside
/// <class>OcuPilot.Install.Installer</class> — so this method never switches
/// <code>$NAMESPACE</code> and there is nothing to restore on the error path. A future
/// story whose resolution needs a <code>%SYS</code>-only call must bracket it with
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
        Set tGate = ..GateStatus()
        If tGate '= "installed" {
            Set pContinue = 0
            If tGate = "failed" {
                Set tCode = ##class(OcuPilot.Api.Error).#INSTALLFAILED
                Set tReason = "Install failed; the API is not serving requests"
            } ElseIf tGate = "upgraderequired" {
                Set tCode = ##class(OcuPilot.Api.Error).#INSTALLUPGRADEREQUIRED
                Set tReason = "A schema upgrade has not finished; the API is not serving requests"
            } Else {
                Set tCode = ##class(OcuPilot.Api.Error).#INSTALLINSTALLING
                Set tReason = "Install is still running; the API is not serving requests"
            }
            Do ##class(OcuPilot.Api.Error).Render(503, ##class(OcuPilot.Api.Error).#UNAVAILABLE, tReason, tCode)
            Quit
        }

        Set tUser = ..ResolvedUsername()
        If (tUser = "") || (tUser = "UnknownUser") || (tUser = "_PUBLIC") {
            Set pContinue = 0
            Do ##class(OcuPilot.Api.Error).Render(401, ##class(OcuPilot.Api.Error).#UNAUTHORIZED, "Authentication required", "AUTH.ANONYMOUS")
            Quit
        }

        If '..HoldsAdminResource() {
            Set pContinue = 0
            Do ##class(OcuPilot.Api.Error).Render(403, ##class(OcuPilot.Api.Error).#FORBIDDEN, "This account holds no InterSystems IRIS administrative privilege; OcuPilot requires USE on at least one %Admin_ resource", ##class(OcuPilot.Api.Error).#AUTHNOADMIN)
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
        ; The code is derived from the slug, not from the number. "ROUTE." _ tStatus
        ; produced ROUTE.403 / ROUTE.500 — a numeric code, which this story's Design
        ; Notes rule out ("a stable dotted uppercase identifier ... rather than a number,
        ; so that adding a code never renumbers an existing one"). This branch is
        ; reachable in production: %CSP.REST.Page() calls ..Http403() at
        ; irislib/%CSP/REST.cls:169 when the security application is undefined.
        Set tSlug = ##class(OcuPilot.Api.Error).GetSlugForStatus(tStatus)
        Do ##class(OcuPilot.Api.Error).Render(tStatus, tSlug, "Request failed", "ROUTE." _ $ZConvert(tSlug, "U"))
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

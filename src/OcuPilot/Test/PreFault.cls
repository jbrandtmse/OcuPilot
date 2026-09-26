/// <p>Test-only fixture for the two <method>OcuPilot.Api.Router.ReportHttpStatusCode</method>
/// branches no other test can reach (DW-25 and DW-34).</p>
/// <p><b>DW-25, the <code>$$$ISERR(pSC)</code> branch.</b> With the
/// <code>_prefault</code> query parameter set, <method>OnPreDispatch</method> returns a
/// failing status without rendering anything.
/// <code>%CSP.REST.DispatchRequest</code> turns that into a thrown error, catches it and
/// <b>returns</b> the status having written no envelope
/// (<file>irislib/%CSP/REST.cls</file>:415-419); the envelope comes one level up, where
/// <code>Page()</code> calls <code>Http500(...)</code>, which calls
/// <method>ReportHttpStatusCode</method> with that status. Both halves are asserted in
/// <class>OcuPilot.Test.Envelope</class>, and the whole chain runs over the wire in
/// <class>OcuPilot.Test.Wire</class>.</p>
/// <p><b>DW-34, the <code>Else</code> branch.</b> <method>Framework403</method> makes the
/// same call <code>%CSP.REST.Page()</code>'s own <code>Http403()</code> makes for an
/// application with no dispatch class — a status with no matching route — so the envelope's
/// code can be asserted as slug-derived (<code>ROUTE.FORBIDDEN</code>) rather than numeric.
/// The framework's own <code>AccessCheck</code> 403 never reaches
/// <method>ReportHttpStatusCode</method> at all, so this is that branch's only reachable
/// caller shape. Measured for DW-1431 on a throwaway container (2026-09-21) rather than
/// inferred: that refusal is answered 403 with an empty body, and it is pinned by
/// <method>OcuPilot.Test.ProhibitedRoute.TestAnAccountWithoutTheCodeDatabaseReadIsRefusedABareForbidden</method>.</p>
/// <p>Extends <class>OcuPilot.Test.RouterFixture</class> and its <code>UrlMap</code>
/// (<code>Extend="true"</code>), so the twelve fixture routes the entity-id corpus and the
/// routing invariants use are all still reachable through this one class — which is what
/// lets a single test-owned web application serve both.</p>
Class OcuPilot.Test.PreFault Extends OcuPilot.Test.RouterFixture
{

/// <p>The query parameter that arms the pre-dispatch failure. A parameter rather than a
/// separate class so the same fixture serves the working routes too.</p>
Parameter FAULTPARAM = "OcuPilotPreFault";

/// <p>Returns a failing status when the fault is armed, otherwise the real inherited
/// gate. Renders nothing on the failing path: whether an envelope reaches the wire is
/// precisely what DW-25 is about, so this fixture must not write one itself.</p>
ClassMethod OnPreDispatch(pUrl As %String, pMethod As %String, ByRef pContinue As %Boolean) As %Status
{
    If %request.Get(..#FAULTPARAM, 0) {
        Quit $$$ERROR($$$GeneralError, "OcuPilot pre-dispatch fixture failure")
    }
    Quit ##super(pUrl, pMethod, .pContinue)
}

/// <p>The DW-34 route. Adds one route to the inherited map; every inherited route still
/// resolves as it did.</p>
XData UrlMap [ XMLNamespace = "http://www.intersystems.com/urlmap" ]
{
<Routes Extend="true">
  <Route Url="/framework403" Method="GET" Call="Framework403" />
</Routes>
}

/// <p>Report a framework status with no matching route, exactly as
/// <code>%CSP.REST.Page()</code>'s <code>Http403()</code> does.</p>
ClassMethod Framework403() As %Status
{
    Quit ..ReportHttpStatusCode(403, $$$OK)
}

}

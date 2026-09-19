/// <p>Fixture: the shipped <code>GET /agent/ledger</code> handler reading
/// <class>OcuPilot.Test.LedgerFaultProbe</class>, whose store refuses every read, so
/// <method>OcuPilot.Api.Ledger.RenderFault</method>'s 503 leg is reachable in process. The
/// validation, the delegation, the status mapping and the envelope are all the shipped code.</p>
/// <p>Driven through <method>OcuPilot.Test.Dispatch.InvokeHandler</method>: the router's
/// <code>UrlMap</code> names <class>OcuPilot.Api.Ledger</class> by class, so a subclass has no route
/// of its own to arrive on.</p>
Class OcuPilot.Test.LedgerRouteProbe Extends OcuPilot.Api.Ledger
{

ClassMethod LedgerClass() As %String
{
    Quit "OcuPilot.Test.LedgerFaultProbe"
}

}

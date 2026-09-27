/// <p>Fixture: the shipped <code>GET /transcripts/:id</code> handler reading
/// <class>OcuPilot.Test.LedgerFaultProbe</class>, whose store refuses every read, so
/// <method>OcuPilot.Api.Transcripts.HandleRead</method>'s 503 leg is reachable in process. The
/// gate, the status mapping and the envelope are all the shipped code.</p>
/// <p>Driven through <method>OcuPilot.Test.Dispatch.InvokeHandlerWithRequest</method>: the
/// router's <code>UrlMap</code> names <class>OcuPilot.Api.Transcripts</class> by class, so a
/// subclass has no route of its own to arrive on -- the same reason
/// <class>OcuPilot.Test.LedgerRouteProbe</class> exists for <class>OcuPilot.Api.Ledger</class>.</p>
Class OcuPilot.Test.TranscriptsRouteProbe Extends OcuPilot.Api.Transcripts
{

ClassMethod LedgerClass() As %String
{
    Quit "OcuPilot.Test.LedgerFaultProbe"
}

}

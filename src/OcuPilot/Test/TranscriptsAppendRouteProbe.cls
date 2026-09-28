/// <p>Fixture: the shipped <code>GET /transcripts/:id</code> handler asking
/// <class>OcuPilot.Test.LedgerAppendProbe</class>, whose gate appends an entry to the conversation
/// after it has answered, so the handler's treatment of an entry the gate never saw is reachable in
/// process. Driven through <method>OcuPilot.Test.Dispatch.InvokeHandlerWithRequest</method>, for the
/// reason <class>OcuPilot.Test.TranscriptsRouteProbe</class> is.</p>
Class OcuPilot.Test.TranscriptsAppendRouteProbe Extends OcuPilot.Api.Transcripts
{

ClassMethod LedgerClass() As %String
{
    Quit "OcuPilot.Test.LedgerAppendProbe"
}

}

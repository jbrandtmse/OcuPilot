/// <p>Fixture: the shipped loop with <method>OcuPilot.Kernel.Agent.Loop.Boundary</method> always
/// answering "stop, <code>TURNSTOPPED</code>", so
/// <method>OcuPilot.Kernel.Agent.Loop.AnswerTools</method>'s boundary-stop refusal -- caught before
/// any call is dispatched, distinct from the reply-budget refusal
/// <class>OcuPilot.Test.LedgerLoopProbe</class> reaches -- can be driven in process. Everything the
/// stop itself does, the stopped step and the ledger row included, is the shipped code.</p>
Class OcuPilot.Test.LedgerLoopStopProbe Extends OcuPilot.Kernel.Agent.Loop
{

/// <p>The dispatcher declaring a secret argument, so the stopped row's layer-1 redaction has
/// something to redact (the same reason <class>OcuPilot.Test.LedgerLoopProbe</class> uses it).</p>
ClassMethod DispatchClass() As %String
{
    Quit "OcuPilot.Test.LedgerDispatchProbe"
}

ClassMethod Boundary(pKey As %String, pUser As %String, pReadOnly As %Boolean, pResources As %String, pStartedSeconds As %Integer, pTokens As %Integer, Output pState As %String, Output pCode As %String) As %Boolean
{
    Set pState = ##class(OcuPilot.Kernel.State.Turn).#STATESTOPPED
    Set pCode = ##class(OcuPilot.Api.Error).#TURNSTOPPED
    Quit 1
}

}

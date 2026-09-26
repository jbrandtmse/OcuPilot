/// <p>Fixture: the same loop as <class>OcuPilot.Test.LedgerClientLoopProbe</class> with a
/// <b>call-counting</b> boundary -- it allows the first question and stops every one after it.</p>
/// <p>That is what reaches
/// <method>OcuPilot.Kernel.Agent.Loop.AnswerClientCall</method>'s in-wait stop.
/// <class>OcuPilot.Test.LedgerLoopStopProbe</class> stops unconditionally, so the per-call check in
/// <method>OcuPilot.Kernel.Agent.Loop.AnswerTools</method> refuses the call before it is ever
/// announced and the wait is never entered; the first question here is that per-call check, and the
/// second is the wait's own first pass.</p>
/// <p>The count lives in <code>^||OcuPilotLedgerClientStop</code>; <method>Reset</method> forgets
/// it, and a test that does not reset it gets a boundary that has already been asked.</p>
Class OcuPilot.Test.LedgerClientStopProbe Extends OcuPilot.Kernel.Agent.Loop
{

ClassMethod Reset()
{
    Kill ^||OcuPilotLedgerClientStop
}

/// <p>How many times the boundary was asked since the last <method>Reset</method>.</p>
ClassMethod Asked() As %Integer
{
    Quit +$Get(^||OcuPilotLedgerClientStop)
}

ClassMethod DispatchClass() As %String
{
    Quit "OcuPilot.Test.LedgerClientDispatchProbe"
}

ClassMethod Boundary(pKey As %String, pUser As %String, pReadOnly As %Boolean, pResources As %String, pStartedSeconds As %Integer, pTokens As %Integer, Output pState As %String, Output pCode As %String) As %Boolean
{
    Set pState = ""
    Set pCode = ""
    If $Increment(^||OcuPilotLedgerClientStop) = 1 Quit 0
    Set pState = ##class(OcuPilot.Kernel.State.Turn).#STATESTOPPED
    Set pCode = ##class(OcuPilot.Api.Error).#TURNSTOPPED
    Quit 1
}

}

/// <p>Test-only loop whose <method>Run</method> throws out of its own frame, counting each call, so
/// the caller's catch path runs. Limits and port are <class>OcuPilot.Test.TurnLoopProbe</class>'s.
/// State lives in <code>^||OcuPilotLoopThrowProbe</code>.</p>
Class OcuPilot.Test.LoopThrowProbe Extends OcuPilot.Test.TurnLoopProbe
{

ClassMethod ResetThrows()
{
    Kill ^||OcuPilotLoopThrowProbe
}

/// <p>How many times <method>Run</method> threw since <method>ResetThrows</method>.</p>
ClassMethod Throws() As %Integer
{
    Quit +$Get(^||OcuPilotLoopThrowProbe)
}

ClassMethod Run(pKey As %String, pUser As %String, pDefinitionId As %String, pMessage As %String, pReadOnly As %Boolean, pResources As %String, pStartedSeconds As %Integer, Output pOutcome, pContext As %String = "", pContextRowCap As %Integer = 0, pConvo As OcuPilot.Kernel.State.Convo = "") As %Status
{
    Set ^||OcuPilotLoopThrowProbe = $Get(^||OcuPilotLoopThrowProbe) + 1
    Throw ##class(%Exception.General).%New("OcuPilotLoopThrowProbe", 5001, , "the probe loop throws")
    Quit $$$OK
}

}

/// <p>Fixture: the shipped loop over <class>OcuPilot.Test.LedgerClientDispatchProbe</class>, with
/// <method>OcuPilot.Kernel.Agent.Loop.Boundary</method> answering "no stop" for the reason
/// <class>OcuPilot.Test.LedgerLoopProbe</class> gives -- the real boundary reads instance switches
/// and a named user's resources, neither of which a probe user has. Everything the client-call path
/// itself does, the announce step, the directive, the wait and the ledger row included, is the
/// shipped code.</p>
Class OcuPilot.Test.LedgerClientLoopProbe Extends OcuPilot.Kernel.Agent.Loop
{

ClassMethod DispatchClass() As %String
{
    Quit "OcuPilot.Test.LedgerClientDispatchProbe"
}

ClassMethod Boundary(pKey As %String, pUser As %String, pReadOnly As %Boolean, pResources As %String, pStartedSeconds As %Integer, pTokens As %Integer, Output pState As %String, Output pCode As %String) As %Boolean
{
    Set pState = ""
    Set pCode = ""
    Quit 0
}

}

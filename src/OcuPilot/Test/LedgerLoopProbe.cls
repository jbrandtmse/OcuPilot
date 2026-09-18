/// <p>Fixture: the shipped loop with <method>OcuPilot.Kernel.Agent.Loop.Boundary</method> answering
/// "no stop", so <method>OcuPilot.Kernel.Agent.Loop.AnswerTools</method>'s reply-budget refusal can
/// be reached in process. The real boundary reads the instance's switches and the named user's
/// resources, neither of which a probe user has and both of which another test may have written --
/// and neither is what a ledger test is about. Everything the refusal itself does, the step and the
/// ledger row included, is the shipped code.</p>
Class OcuPilot.Test.LedgerLoopProbe Extends OcuPilot.Kernel.Agent.Loop
{

/// <p>The dispatcher above, so a refusal resolves a tool that declares a secret argument.</p>
ClassMethod DispatchClass() As %String
{
    Quit "OcuPilot.Test.LedgerDispatchProbe"
}

ClassMethod Boundary(pKey As %String, pUser As %String, pReadOnly As %Boolean, pResources As %String, pStartedSeconds As %Integer, pTokens As %Integer, Output pState As %String, Output pCode As %String) As %Boolean
{
    Set pState = ""
    Set pCode = ""
    Quit 0
}

}

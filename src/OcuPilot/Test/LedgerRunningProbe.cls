/// <p>Fixture: <class>OcuPilot.Test.LedgerLoopProbe</class> with the dispatch itself refused, so the
/// tool step <method>OcuPilot.Kernel.Agent.Loop.AnswerTools</method> appends <code>running</code>
/// <b>before</b> a call is dispatched keeps that string. On the ordinary path
/// <method>OcuPilot.Kernel.State.Step.GuardedFinishTool</method> overwrites it with the
/// dispatcher's own, so the pre-dispatch string is otherwise unobservable to a test and its
/// redaction could be removed unnoticed.</p>
Class OcuPilot.Test.LedgerRunningProbe Extends OcuPilot.Test.LedgerLoopProbe
{

/// <p>Refuse, with the outputs the caller reads initialized: the refusal branch finishes the tool
/// step from the pre-dispatch argument string and stops the reply.</p>
ClassMethod DispatchTools(pKey As %String, pUser As %String, pDefinitionId As %String, pToolUses As %DynamicArray, pLimitsClass As %String, Output pResults As %DynamicArray, Output pNames As %DynamicArray, pRowCap As %Integer = 0, pMaxLength As %Integer = 0, Output pDetails As %DynamicArray, pRoute As %String = "") As %Status
{
    Set pResults = []
    Set pNames = []
    Set pDetails = []
    Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.LedgerRunningProbe refuses every dispatch")
}

}

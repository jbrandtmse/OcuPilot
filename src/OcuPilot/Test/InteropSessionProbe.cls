/// <p>Test-only <class>OcuPilot.Kernel.Agent.Dispatch</class> subclass that records the order of what a call asks: the governance gate
/// (with the tool's name and kind), each privilege pair, and the ledger. A pair is held unless <method>Deny</method> names it, because
/// the suite's own account holds <code>%All</code>. The ledger is replaced by a no-op, so a call leaves no row. The registry is the
/// shipped one, and the gate's decision is the shipped gate's. No method of the dispatcher itself is replaced.</p>
/// <p>State lives in <code>^||OcuPilotInteropSessionProbe</code>; <method>Reset</method> forgets it. Not a
/// <class>%UnitTest.TestCase</class>.</p>
Class OcuPilot.Test.InteropSessionProbe Extends OcuPilot.Kernel.Agent.Dispatch
{

ClassMethod Reset()
{
    Kill ^||OcuPilotInteropSessionProbe
}

/// <p>Answer the pair <var>pResource</var>:<var>pPermission</var> as not held.</p>
ClassMethod Deny(pResource As %String, pPermission As %String)
{
    Set ^||OcuPilotInteropSessionProbe("deny", pResource _ ":" _ pPermission) = 1
}

ClassMethod Note(pEvent As %String)
{
    Set ^||OcuPilotInteropSessionProbe("events", $Increment(^||OcuPilotInteropSessionProbe("events"))) = pEvent
}

/// <p>What was asked since <method>Reset</method>, in order, comma-separated: <code>gate:&lt;tool&gt;:&lt;kind&gt;</code>,
/// <code>pair:&lt;resource&gt;:&lt;permission&gt;</code> and <code>ledger</code>.</p>
ClassMethod Events() As %String
{
    Set tText = ""
    For tI = 1:1:+$Get(^||OcuPilotInteropSessionProbe("events")) {
        Set tText = tText _ $Select(tI = 1: "", 1: ",") _ ^||OcuPilotInteropSessionProbe("events", tI)
    }
    Quit tText
}

/// <p>This class, so <method>Decide</method> is asked every gate question.</p>
ClassMethod GateClass() As %String
{
    Quit "OcuPilot.Test.InteropSessionProbe"
}

ClassMethod Decide(pTool As %String, pKind As %String, pUser As %String, pArgs As %DynamicAbstractObject, Output pDecision) As %Status
{
    Do ..Note("gate:" _ pTool _ ":" _ pKind)
    Quit ##class(OcuPilot.Kernel.Governance.Gate).Decide(pTool, pKind, pUser, pArgs, .pDecision)
}

ClassMethod HoldsPair(pUser As %String, pResource As %String, pPermission As %String) As %Boolean
{
    Do ..Note("pair:" _ pResource _ ":" _ pPermission)
    Quit '$Get(^||OcuPilotInteropSessionProbe("deny", pResource _ ":" _ pPermission))
}

/// <p>This class, so the ledger's three calls are noted and write nothing.</p>
ClassMethod LedgerClass() As %String
{
    Quit "OcuPilot.Test.InteropSessionProbe"
}

ClassMethod SenseChecked() As %String
{
    Quit "checked"
}

ClassMethod SenseFor(pSense As %String, pPairs As %List, pPairsRead As %Boolean) As %String
{
    Quit pSense
}

ClassMethod RecordToolCall(pArgs...) As %Status
{
    Do ..Note("ledger")
    Quit $$$OK
}

ClassMethod LogFault(pMessage As %String, pStatus As %Status, pCode As %String)
{
    Do ..Note("fault:" _ pCode)
}

/// <p>One call to wire name <var>pWire</var> with <var>pInput</var>, as the running user, answered as the dispatcher answers a turn's
/// tool call: <var>pResult</var> is the <code>tool_result</code> block.</p>
ClassMethod Ask(pWire As %String, pInput As %DynamicObject, Output pResult As %DynamicObject) As %Status
{
    Set tUse = {"type": "tool_use", "id": "toolu_probe"}
    Do tUse.%Set("name", pWire, "string")
    Do tUse.%Set("input", pInput)
    Set tUses = []
    Do tUses.%Push(tUse)
    Set tSC = ..Answer("probe2404", $Username, "", tUses, "OcuPilot.Kernel.Agent.Limits", .tResults, .tNames)
    Set pResult = $Select($IsObject($Get(tResults)): tResults.%Get(0), 1: {})
    Quit tSC
}

}

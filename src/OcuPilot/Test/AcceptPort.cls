/// <p>Fixture: a port that accepts every call and changes nothing, answering an empty result at 200,
/// so <method>OcuPilot.Kernel.Proposal.Operation.ApplyAt</method> reaches a tool's own
/// <code>AfterWrite</code> without the vendor write happening (<class>OcuPilot.Test.ToolWrite</class>'s
/// deleted-account leg). The request types it was asked for are recorded in
/// <code>^||OcuPilotAcceptCalls</code>. <method>ReadThrough</method> sends the reads to the instance
/// instead.</p>
Class OcuPilot.Test.AcceptPort Extends OcuPilot.Port.AdminPort
{

ClassMethod Invoke(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set ^||OcuPilotAcceptCalls($Increment(^||OcuPilotAcceptCalls)) = pType
    If $Get(^||OcuPilotAcceptReadThrough) && '..IsMutating(pEndpoint, pType) Quit ##super(pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
    Set pResult = {}
    Set pHttpStatus = 200
    Set pFault = ""
    Quit $$$OK
}

/// <p>The request types asked for since <method>Clear</method>, comma-separated.</p>
ClassMethod CallTypes() As %String
{
    Set tTypes = ""
    For tI = 1:1:+$Get(^||OcuPilotAcceptCalls) {
        Set tTypes = tTypes _ $Select(tI = 1: "", 1: ",") _ $Get(^||OcuPilotAcceptCalls(tI))
    }
    Quit tTypes
}

ClassMethod Clear()
{
    Kill ^||OcuPilotAcceptCalls
}

/// <p>With <var>pOn</var> 1, answer every non-mutating call through the shipped port, so a read sees
/// the instance while a write is still recorded and never sent; 0 restores answering every call
/// here. Off unless a test turns it on.</p>
ClassMethod ReadThrough(pOn As %Boolean = 1)
{
    If pOn {
        Set ^||OcuPilotAcceptReadThrough = 1
    } Else {
        Kill ^||OcuPilotAcceptReadThrough
    }
}

}

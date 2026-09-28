/// <p>Fixture: a port that accepts every call and changes nothing, answering an empty result at 200,
/// so <method>OcuPilot.Kernel.Proposal.Operation.ApplyAt</method> reaches a tool's own
/// <code>AfterWrite</code> without the vendor write happening (<class>OcuPilot.Test.ToolWrite</class>'s
/// deleted-account leg). The request types it was asked for are recorded in
/// <code>^||OcuPilotAcceptCalls</code>.</p>
Class OcuPilot.Test.AcceptPort Extends OcuPilot.Port.AdminPort
{

ClassMethod Invoke(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set ^||OcuPilotAcceptCalls($Increment(^||OcuPilotAcceptCalls)) = pType
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

}

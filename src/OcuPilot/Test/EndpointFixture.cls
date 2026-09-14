/// <p>Stand-in admin endpoint for <method>OcuPilot.Port.AdminPort.Invoke</method>, reached through
/// <method>OcuPilot.Test.PortFixture.SetEndpointClass</method>. It answers every call the port's
/// sequence makes, records each call in order, and fails one way at a time under
/// <method>SetMode</method>, so the sequence's outcome rules are pinned without a vendor endpoint
/// and without changing anything on the instance.</p>
/// <p>It extends no vendor class (AD-27): the port calls it through dynamic dispatch. State lives
/// in the process-private global <code>^||OcuPilotEndpointFixture</code>, because the port
/// constructs this class itself and runs it in <code>%SYS</code>.</p>
Class OcuPilot.Test.EndpointFixture Extends %RegisteredObject
{

/// <p>The vendor's list type number.</p>
Parameter TYPELIST As INTEGER = 0;

/// <p>The vendor's get type number.</p>
Parameter TYPEGET As INTEGER = 1;

/// <p>Declared so a refusal of <code>PUT</code> is the port's suffix list refusing it, not a
/// missing parameter.</p>
Parameter TYPEPUT As INTEGER = 2;

/// <p>The task id the <code>accepted</code> mode's <code>Location</code> carries.</p>
Parameter TASKGUID = "424242424242";

/// <p>Class-shaped text no instance message carries, so an assertion that it never reaches a
/// fault cannot pass by a reworded vendor message.</p>
Parameter FAULTTEXT = "%Vendor.Internal.Endpoints.EndpointFixtureFault";

Property Type As %Integer;

Property ApiVersion As %Integer;

Property IsRunningAsync As %Boolean;

Property Name As %String;

/// <p>Arm one behaviour of <code>Run()</code>: <code>ok</code> (the default) returns
/// <code>{"fixture": "ok"}</code>; <code>notfound</code> sets <code>404 Not Found</code> and
/// leaves the status OK; <code>errorstatus</code> returns an error status carrying
/// <parameter>FAULTTEXT</parameter> and leaves the HTTP status alone; <code>protect</code>
/// throws a <code>&lt;PROTECT&gt;</code> system exception; <code>device</code> writes to the
/// current device and returns <code>{"fixture": "device"}</code>; <code>accepted</code> answers
/// <code>202</code> with an <code>async-result</code> location naming
/// <parameter>TASKGUID</parameter>, queuing nothing; <code>queryinvalid</code> makes
/// <code>ValidateQueryParams()</code> throw; <code>requestinvalid</code> makes
/// <code>ValidateRequest()</code> return an error status carrying <parameter>FAULTTEXT</parameter>.</p>
ClassMethod SetMode(pMode As %String)
{
    Set ^||OcuPilotEndpointFixture("mode") = pMode
}

/// <p>Forget the armed mode and every record.</p>
ClassMethod Clear()
{
    Kill ^||OcuPilotEndpointFixture
}

/// <p>A recorded value: <code>constructed</code> (1 once constructed), <code>type</code>,
/// <code>apiVersion</code>, <code>trace</code> (the calls in order, comma-separated),
/// <code>asyncAtRun</code> (<code>IsRunningAsync</code> when <code>Run()</code> started) or
/// <code>nameAtRun</code>. <code>""</code> when never recorded.</p>
ClassMethod Recorded(pKey As %String) As %String
{
    Quit $Get(^||OcuPilotEndpointFixture(pKey), "")
}

ClassMethod Note(pCall As %String) [ Private ]
{
    Set tTrace = $Get(^||OcuPilotEndpointFixture("trace"), "")
    Set ^||OcuPilotEndpointFixture("trace") = tTrace _ $Select(tTrace = "": "", 1: ",") _ pCall
}

Method %OnNew(pType As %Integer = -1, pApiVersion As %Integer = 1) As %Status
{
    Set ..Type = pType
    Set ..ApiVersion = pApiVersion
    Set ^||OcuPilotEndpointFixture("constructed") = 1
    Set ^||OcuPilotEndpointFixture("type") = pType
    Set ^||OcuPilotEndpointFixture("apiVersion") = pApiVersion
    Quit $$$OK
}

Method ResourcesOR() As %List
{
    Do ..Note("ResourcesOR")
    Quit $ListBuild("%Admin_Operate", "%Admin_Manage")
}

/// <p>Reads the seeded query parameter from <code>%request.Data</code>, as the vendor's does.</p>
Method SaveQueryParams()
{
    Do ..Note("SaveQueryParams")
    Set ^||OcuPilotEndpointFixture("query") = $Get(%request.Data("name", 1), "")
}

Method ValidateQueryParams()
{
    Do ..Note("ValidateQueryParams")
    If $Get(^||OcuPilotEndpointFixture("mode")) = "queryinvalid" {
        Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError, ..#FAULTTEXT))
    }
    Set ..Name = $Get(^||OcuPilotEndpointFixture("query"), "")
}

Method ValidateRequest(pBody As %DynamicAbstractObject) As %Status
{
    Do ..Note("ValidateRequest")
    If $Get(^||OcuPilotEndpointFixture("mode")) = "requestinvalid" Quit $$$ERROR($$$GeneralError, ..#FAULTTEXT)
    Quit $$$OK
}

Method ValidateSemantics() As %Status
{
    Do ..Note("ValidateSemantics")
    Quit $$$OK
}

Method ShouldRunAsync() As %Boolean
{
    Do ..Note("ShouldRunAsync")
    Quit 0
}

Method Run(ByRef pSC As %Status, pBody As %DynamicAbstractObject) As %DynamicAbstractObject
{
    Do ..Note("Run")
    Set ^||OcuPilotEndpointFixture("asyncAtRun") = +..IsRunningAsync
    Set ^||OcuPilotEndpointFixture("nameAtRun") = ..Name
    Set tMode = $Get(^||OcuPilotEndpointFixture("mode"), "ok")
    If tMode = "notfound" {
        Do ..SetRespStatus("404 Not Found")
        Quit {}
    }
    If tMode = "errorstatus" {
        Set pSC = $$$ERROR($$$GeneralError, ..#FAULTTEXT)
        Quit {}
    }
    If tMode = "protect" {
        Throw ##class(%Exception.SystemException).%New("<PROTECT>", 1, , "endpoint fixture")
    }
    If tMode = "device" {
        Set tOutput = {"fixture": "device output"}
        Do tOutput.%ToJSON()
        Quit {"fixture": "device"}
    }
    If tMode = "accepted" {
        Do ..SetRespStatus("202 Accepted")
        If '..IsRunningAsync Do %response.SetHeader("Location", "/api/admin/v1/async-result?id=" _ ..#TASKGUID)
        Quit {}
    }
    Quit {"fixture": "ok"}
}

/// <p>Guarded by <code>IsRunningAsync</code>, as the vendor's base class guards it.</p>
Method SetRespStatus(pStatus As %String)
{
    If '..IsRunningAsync Set %response.Status = pStatus
}

}

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
/// <code>ValidateRequest()</code> return an error status carrying <parameter>FAULTTEXT</parameter>;
/// <code>list</code> returns the rows <method>SetRows</method> armed, stopping at the seeded
/// <code>maxRows</code> as the vendor's class query does, and answers a <code>TYPEGET</code> call
/// with the detail <method>SetDetails</method> armed for its <code>name</code>: 404 for a name with
/// no detail, the fault <method>SetDetailFault</method> armed for one, and each name appended to
/// <code>Recorded("getNames")</code>.</p>
ClassMethod SetMode(pMode As %String)
{
    Set ^||OcuPilotEndpointFixture("mode") = pMode
}

/// <p>Arm the rows the <code>list</code> mode answers, as a JSON array. Stored as JSON because a
/// process-private global cannot hold an OREF.</p>
ClassMethod SetRows(pJson As %String)
{
    Set ^||OcuPilotEndpointFixture("rows") = pJson
}

/// <p>Arm the details the <code>list</code> mode's <code>TYPEGET</code> answers, as a JSON object
/// keyed by name; a value is answered as it is, object or not.</p>
ClassMethod SetDetails(pJson As %String)
{
    Set ^||OcuPilotEndpointFixture("details") = pJson
}

/// <p>Arm a fault for the <code>list</code> mode's <code>TYPEGET</code> of <var>pName</var>:
/// <code>notfound</code> (404 with an OK status), <code>forbidden</code> (403 with an OK status) or
/// <code>errorstatus</code> (an error status carrying <parameter>FAULTTEXT</parameter>).</p>
ClassMethod SetDetailFault(pName As %String, pMode As %String)
{
    Set ^||OcuPilotEndpointFixture("detailFault", pName) = pMode
}

/// <p>Forget the armed mode and every record.</p>
ClassMethod Clear()
{
    Kill ^||OcuPilotEndpointFixture
}

/// <p>A recorded value: <code>constructed</code> (1 once constructed), <code>type</code>,
/// <code>apiVersion</code>, <code>trace</code> (the calls in order, comma-separated),
/// <code>asyncAtRun</code> (<code>IsRunningAsync</code> when <code>Run()</code> started),
/// <code>nameAtRun</code>, <code>sessionUserAtRun</code> (<code>%session.Username</code>),
/// <code>captureAtWrite</code> (in <code>device</code> mode, 1 when the write landed in a capture
/// -- the vendor's buffer is defined once a capture holds output, so this says the write happened
/// <b>inside</b> a capture window rather than only that it happened),
/// <code>maxRows</code> (the seeded <code>maxRows</code> query parameter, kept across a call that
/// seeds none) or <code>getNames</code> (the names the <code>list</code> mode's
/// <code>TYPEGET</code> calls asked for, comma-separated, in order) or <code>getCount</code> (how
/// many <code>TYPEGET</code> calls it answered). <code>""</code> when never
/// recorded.</p>
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
    If $Data(%request.Data("maxRows", 1)) || '$Data(^||OcuPilotEndpointFixture("maxRows")) Set ^||OcuPilotEndpointFixture("maxRows") = $Get(%request.Data("maxRows", 1), "")
    ; Every seeded key, not only the two this fixture models: a declared server-search criterion is
    ; named by the descriptor, so a test cannot ask for it by a name this class knows in advance.
    Set tParams = ""
    Set tKey = ""
    For {
        Set tKey = $Order(%request.Data(tKey))
        If tKey = "" Quit
        Set tParams = tParams _ $Select(tParams = "": "", 1: "&") _ tKey _ "=" _ $Get(%request.Data(tKey, 1), "")
    }
    Set ^||OcuPilotEndpointFixture("params") = tParams
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
    If $IsObject($Get(%session)) Set ^||OcuPilotEndpointFixture("sessionUserAtRun") = %session.Username
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
        Set ^||OcuPilotEndpointFixture("captureAtWrite") = ''$Data(^||%capture)
        Quit {"fixture": "device"}
    }
    If (tMode = "list") && (..Type = ..#TYPEGET) {
        Set tNames = $Get(^||OcuPilotEndpointFixture("getNames"), "")
        Set ^||OcuPilotEndpointFixture("getNames") = tNames _ $Select(tNames = "": "", 1: ",") _ ..Name
        Set ^||OcuPilotEndpointFixture("getCount") = $Get(^||OcuPilotEndpointFixture("getCount"), 0) + 1
        Set tFault = $Select(..Name = "": "", 1: $Get(^||OcuPilotEndpointFixture("detailFault", ..Name), ""))
        If tFault = "errorstatus" {
            Set pSC = $$$ERROR($$$GeneralError, ..#FAULTTEXT)
            Quit {}
        }
        If tFault = "forbidden" {
            Do ..SetRespStatus("403 Forbidden")
            Quit {}
        }
        Set tDetails = ##class(%DynamicObject).%FromJSON($Get(^||OcuPilotEndpointFixture("details"), "{}"))
        If (tFault = "notfound") || ((..Name '= "") && (tDetails.%GetTypeOf(..Name) = "unassigned")) {
            Do ..SetRespStatus("404 Not Found")
            Quit {}
        }
        Quit tDetails.%Get(..Name)
    }
    If tMode = "list" {
        Set tRows = ##class(%DynamicArray).%FromJSON($Get(^||OcuPilotEndpointFixture("rows"), "[]"))
        Set tMax = +$Get(^||OcuPilotEndpointFixture("maxRows"), 0)
        Set tAnswer = []
        Set tIterator = tRows.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tRow) {
            If (tMax > 0) && (tAnswer.%Size() >= tMax) Quit
            Do tAnswer.%Push(tRow)
        }
        Quit tAnswer
    }
    If tMode = "accepted" {
        Do ..SetRespStatus("202 Accepted")
        If '..IsRunningAsync Do %response.SetHeader("Location", "/api/admin/v2/async-result?id=" _ ..#TASKGUID)
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

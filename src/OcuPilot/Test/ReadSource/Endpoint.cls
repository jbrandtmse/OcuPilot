/// <p>Stand-in admin endpoint for the single-object and per-parent read shapes (AD-36), reached
/// through <method>OcuPilot.Test.PortFixture.SetEndpointClass</method> by
/// <class>OcuPilot.Test.Read.ReadFixture</class>. It answers by the request path the port builds from
/// the endpoint name: <code>Test.Object</code> a GET, <code>Test.Parents</code> the parent LIST and
/// <code>Test.Children</code> one parent's child LIST, read for its <code>parentKey</code>;
/// <code>Test.Fixed</code> and <code>Test.Upcoming</code> record the query and request type they were
/// issued with and answer the armed <code>rows</code>.</p>
/// <p>It extends no vendor class (AD-27). State lives in <code>^||OcuPilotReadSource</code>, armed by
/// <method>Arm</method> and cleared by <method>Clear</method>, because the port constructs this class
/// itself and runs it in <code>%SYS</code>.</p>
Class OcuPilot.Test.ReadSource.Endpoint Extends %RegisteredObject
{

/// <p>The vendor's list type number.</p>
Parameter TYPELIST As INTEGER = 0;

/// <p>The vendor's get type number.</p>
Parameter TYPEGET As INTEGER = 1;

/// <p><code>Task.CRUD</code>'s scheduled-occurrence type number.</p>
Parameter TYPEUPCOMING As INTEGER = 13;

Property Type As %Integer;

Property ApiVersion As %Integer;

Property IsRunningAsync As %Boolean;

/// <p>Arm <var>pKey</var> with <var>pValue</var>: <code>rows</code> (a JSON array),
/// <code>parents</code> (a JSON array),
/// <code>parentsUncapped</code> (<code>1</code> answers every parent whatever <code>maxRows</code>
/// asks), <code>parentFault</code>, <code>object</code> (a JSON object), <code>objectFault</code>,
/// or, with <var>pParent</var>, <code>children</code> (a JSON array) or <code>childFault</code> for
/// that parent key. A fault is <code>notfound</code> (404), <code>badrequest</code> (400) or
/// <code>errorstatus</code> (an error status, which the port answers 500).</p>
ClassMethod Arm(pKey As %String, pValue As %String, pParent As %String = "")
{
    If pParent = "" {
        Set ^||OcuPilotReadSource(pKey) = pValue
    } Else {
        Set ^||OcuPilotReadSource(pKey, pParent) = pValue
    }
}

/// <p>A recorded value: <code>parentMaxRows</code>, <code>childKeys</code> (the parent keys the child
/// lists were issued for, comma-separated, in order), <code>childMaxRows</code> (their
/// <code>maxRows</code>, likewise), or, for <code>Test.Fixed</code> and <code>Test.Upcoming</code>,
/// <code>type</code> (the request type number) and <code>query</code> (every query parameter as
/// <code>name=value</code>, comma-separated, in name order), which <code>Test.Object</code> and each
/// child list also record, and <code>parentQuery</code>, the parent list's. <code>""</code> when never
/// recorded.</p>
ClassMethod Recorded(pKey As %String) As %String
{
    Quit $Get(^||OcuPilotReadSource("recorded", pKey), "")
}

/// <p>Forget everything armed and recorded.</p>
ClassMethod Clear()
{
    Kill ^||OcuPilotReadSource
}

/// <p>Append <var>pValue</var> to the comma-separated record <var>pKey</var>.</p>
ClassMethod Note(pKey As %String, pValue As %String) [ Private ]
{
    Set tText = $Get(^||OcuPilotReadSource("recorded", pKey), "")
    Set ^||OcuPilotReadSource("recorded", pKey) = tText _ $Select(tText = "": "", 1: ",") _ pValue
}

Method %OnNew(pType As %Integer = -1, pApiVersion As %Integer = 1) As %Status
{
    Set ..Type = pType
    Set ..ApiVersion = pApiVersion
    Quit $$$OK
}

Method ResourcesOR() As %List
{
    Quit $ListBuild("%Admin_Operate", "%Admin_Manage")
}

Method SaveQueryParams()
{
}

Method ValidateQueryParams()
{
}

Method ValidateRequest(pBody As %DynamicAbstractObject) As %Status
{
    Quit $$$OK
}

Method ValidateSemantics() As %Status
{
    Quit $$$OK
}

Method ShouldRunAsync() As %Boolean
{
    Quit 0
}

Method Run(ByRef pSC As %Status, pBody As %DynamicAbstractObject) As %DynamicAbstractObject
{
    Set tPath = $ZConvert($Piece(%request.URL, "/ocupilot/", 2), "L")
    Set tMax = +$Get(%request.Data("maxRows", 1))
    If tPath = "test/object" {
        Do ..NoteQuery("query")
        If ..Faulted($Get(^||OcuPilotReadSource("objectFault"), ""), .pSC) Quit {}
        Quit ##class(%DynamicObject).%FromJSON($Get(^||OcuPilotReadSource("object"), "{}"))
    }
    If tPath = "test/parents" {
        Do ..Note("parentMaxRows", tMax)
        Do ..NoteQuery("parentQuery")
        If ..Faulted($Get(^||OcuPilotReadSource("parentFault"), ""), .pSC) Quit {}
        Quit ..Capped($Get(^||OcuPilotReadSource("parents"), "[]"), $Select($Get(^||OcuPilotReadSource("parentsUncapped")): 0, 1: tMax))
    }
    If (tPath = "test/fixed") || (tPath = "test/upcoming") {
        Do ..Note("type", ..Type)
        Do ..NoteQuery("query")
        Quit ..Capped($Get(^||OcuPilotReadSource("rows"), "[]"), tMax)
    }
    If tPath = "test/children" {
        Set tParent = $Get(%request.Data("parentKey", 1))
        Do ..Note("childKeys", tParent)
        Do ..Note("childMaxRows", tMax)
        Do ..NoteQuery("query")
        If ..Faulted($Get(^||OcuPilotReadSource("childFault", tParent), ""), .pSC) Quit {}
        Quit ..Capped($Get(^||OcuPilotReadSource("children", tParent), "[]"), tMax)
    }
    Do ..SetRespStatus("404 Not Found")
    Quit {}
}

/// <p>Append every query parameter of this request to the record <var>pKey</var>, as
/// <code>name=value</code> in name order.</p>
Method NoteQuery(pKey As %String) [ Private ]
{
    Set tName = ""
    For {
        Set tName = $Order(%request.Data(tName))
        If tName = "" Quit
        Do ..Note(pKey, tName _ "=" _ $Get(%request.Data(tName, 1)))
    }
}

/// <p>Whether the armed fault <var>pFault</var> answers this request, setting its response status or,
/// for <code>errorstatus</code>, <var>pSC</var>.</p>
Method Faulted(pFault As %String, ByRef pSC As %Status) As %Boolean [ Private ]
{
    If pFault = "notfound" Do ..SetRespStatus("404 Not Found")
    If pFault = "badrequest" Do ..SetRespStatus("400 Bad Request")
    If pFault = "errorstatus" Set pSC = $$$ERROR($$$GeneralError, "read source fixture fault")
    Quit (pFault = "notfound") || (pFault = "badrequest") || (pFault = "errorstatus")
}

/// <p>The JSON array <var>pJson</var>, stopped at <var>pMax</var> rows as the vendor's class query
/// stops, or whole when <var>pMax</var> is 0.</p>
ClassMethod Capped(pJson As %String, pMax As %Integer) As %DynamicArray [ Private ]
{
    Set tRows = ##class(%DynamicArray).%FromJSON(pJson)
    Set tAnswer = []
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If (pMax > 0) && (tAnswer.%Size() >= pMax) Quit
        Do tAnswer.%Push(tRow)
    }
    Quit tAnswer
}

/// <p>Guarded by <code>IsRunningAsync</code>, as the vendor's base class guards it.</p>
Method SetRespStatus(pStatus As %String)
{
    If '..IsRunningAsync Set %response.Status = pStatus
}

}

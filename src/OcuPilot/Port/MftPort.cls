/// <p>The managed file transfer connections' port (AD-27, AD-52, Story 18.26):
/// <class>OcuPilot.Port.AdminPort</class> with two things added on <code>Security.MFT</code>, and every other
/// call the admin port's own, unchanged. It names no vendor class.</p>
/// <p><b>A composed read.</b> <parameter>STATETYPE</parameter> answers the connection's <code>GET</code> (its five
/// fields) with <code>IsAuthorized</code> from the <code>LIST</code> row whose <code>Name</code> equals the id
/// exactly, the revoke's fresh read (AD-51). An id no row names is 404. A connection the row reads
/// "Not Authorized" is 409 <parameter>OcuPilot.Api.MftConnectionError.TOKENNONE</parameter>, because the
/// vendor's revoke answers 200 and changes nothing for a connection that holds no token.</p>
/// <p><b>A delete is judged by a re-read.</b> The vendor's <code>DELETE</code> removes the connection and then
/// deletes its OAuth 2.0 client configuration, and answers 500 (#5809) when that client is absent, with the
/// connection already gone (measured at Story 18.26's plan). A <code>DELETE</code> answered with an error other
/// than 404 is therefore re-read through <code>GET</code>: a 404 there is the delete done, answered 200 with
/// <code>{}</code>; any other answer keeps the first fault. The vendor's 500 is still logged by the admin
/// port.</p>
/// <p><b>Caller contract:</b> every vendor call goes through <method>Call</method>, so a test port overrides
/// that one method.</p>
Class OcuPilot.Port.MftPort Extends OcuPilot.Port.AdminPort
{

/// <p>The endpoint this port composes on.</p>
Parameter ENDPOINT = "Security.MFT";

/// <p>The composed read's request type.</p>
Parameter STATETYPE = "STATE";

/// <p>The vendor's query key for one connection, and the request types this port reads and judges.</p>
Parameter IDQUERY = "connection";

Parameter LISTTYPE = "LIST";

Parameter READTYPE = "GET";

Parameter DELETETYPE = "DELETE";

/// <p>The member of the <code>LIST</code> row that says the connection holds a token, and its value when it
/// holds none.</p>
Parameter AUTHFIELD = "IsAuthorized";

Parameter NOTAUTHORIZED = "Not Authorized";

/// <p>The step a delete's script ends with: what this port does when the vendor answers an error.</p>
Parameter DELETENOTE = "If the instance answers an error after this call, the connection is read again, and one that is gone counts as deleted: the instance deletes the connection before it reports that its OAuth 2.0 client configuration is absent.";

/// <p>One vendor call: <method>OcuPilot.Port.AdminPort.Invoke</method>. Every call this port makes goes
/// through here.</p>
ClassMethod Call(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Quit ##class(OcuPilot.Port.AdminPort).Invoke(pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
}

/// <p>The admin port's call, with <parameter>STATETYPE</parameter> composed and a <code>DELETE</code> the
/// instance answered with an error judged by a re-read.</p>
/// <p><b>Caller contract:</b> the arguments and outputs are <method>OcuPilot.Port.AdminPort.Invoke</method>'s.
/// A <parameter>STATETYPE</parameter> read answers the connection's own object with
/// <code>IsAuthorized</code>; a <code>DELETE</code> answered 404 is the vendor's fault, not a delete done.</p>
ClassMethod Invoke(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    If pEndpoint '= ..#ENDPOINT Quit ..Call(pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
    If pType = ..#STATETYPE Quit ..State(.pQuery, .pResult, .pHttpStatus, .pFault)
    If pType = ..#DELETETYPE Quit ..Delete(.pQuery, pBody, .pResult, .pHttpStatus, .pFault)
    Quit ..Call(pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
}

/// <p>The composed read: the connection's <code>GET</code>, then the <code>LIST</code> row whose
/// <code>Name</code> equals the id exactly, whose <code>IsAuthorized</code> joins the answer. A connection the
/// row reads "Not Authorized" is refused 409 <parameter>OcuPilot.Api.MftConnectionError.TOKENNONE</parameter>.</p>
ClassMethod State(ByRef pQuery, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Set tId = $Get(pQuery(..#IDQUERY))
    Kill tGet
    Merge tGet = pQuery
    Set tSC = ..Call(..#ENDPOINT, ..#READTYPE, .tGet, "", .tRead, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    If '$IsObject($Get(tRead)) || 'tRead.%IsA("%Library.DynamicObject") Quit ..Fail(..#ENDPOINT, 404, $$$OK, .pHttpStatus, .pFault, "", "", 1)
    Kill tList
    Set tSC = ..Call(..#ENDPOINT, ..#LISTTYPE, .tList, "", .tRows, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Set tRow = ..Row(tId, $Get(tRows))
    If '$IsObject(tRow) Quit ..Fail(..#ENDPOINT, 404, $$$OK, .pHttpStatus, .pFault, "", "", 1)
    Set tAuthorized = ..Text(tRow, ..#AUTHFIELD)
    Do tRead.%Set(..#AUTHFIELD, tAuthorized, "string")
    If tAuthorized = ..#NOTAUTHORIZED {
        Quit ..Refuse(409, ##class(OcuPilot.Api.Error).#CONFLICT, ##class(OcuPilot.Api.MftConnectionError).#TOKENNONE, ##class(OcuPilot.Api.MftConnectionError).#REASONTOKENNONE, .pHttpStatus, .pFault)
    }
    Set pResult = tRead
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>The vendor's <code>DELETE</code>; when it answers an error other than 404, a re-read by
/// <code>GET</code>: 404 there is the delete done, answered 200 with <code>{}</code>.</p>
ClassMethod Delete(ByRef pQuery, pBody As %DynamicAbstractObject, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Kill tQuery
    Merge tQuery = pQuery
    Set tSC = ..Call(..#ENDPOINT, ..#DELETETYPE, .tQuery, pBody, .pResult, .pHttpStatus, .pFault)
    If $$$ISOK(tSC) || (+$Get(pHttpStatus) = 404) Quit tSC
    Set tFirstStatus = pHttpStatus
    Set tFirstFault = pFault
    Kill tGet
    Merge tGet = pQuery
    Set tReadSC = ..Call(..#ENDPOINT, ..#READTYPE, .tGet, "", .tRead, .tReadHttp, .tReadFault)
    If $$$ISOK(tReadSC) || (+$Get(tReadHttp) '= 404) {
        Set pHttpStatus = tFirstStatus
        Set pFault = tFirstFault
        Quit tSC
    }
    Set pResult = {}
    Set pHttpStatus = 200
    Set pFault = ""
    Quit $$$OK
}

/// <p>The one row of <var>pRows</var> -- a <code>LIST</code> answer -- whose <code>Name</code> equals
/// <var>pId</var> exactly, or <code>""</code>.</p>
ClassMethod Row(pId As %String, pRows) As %DynamicObject
{
    Set tFound = ""
    If (pId = "") || '$IsObject(pRows) || 'pRows.%IsA("%Library.DynamicArray") Quit tFound
    Set tIterator = pRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If '$IsObject(tRow) || 'tRow.%IsA("%Library.DynamicObject") Continue
        If (tRow.%GetTypeOf("Name") '= "string") || (tRow.%Get("Name") '= pId) Continue
        Set tFound = tRow
        Quit
    }
    Quit tFound
}

/// <p><var>pObject</var>'s <var>pField</var> as text: absent, null, an object or an array as
/// <code>""</code>.</p>
ClassMethod Text(pObject As %DynamicObject, pField As %String) As %String [ Private ]
{
    Set tType = pObject.%GetTypeOf(pField)
    If (tType = "unassigned") || (tType = "null") || (tType = "object") || (tType = "array") Quit ""
    Quit pObject.%Get(pField) _ ""
}

/// <p>The admin port's answer: this port's calls are the vendor's own routes.</p>
ClassMethod SnippetForm(pEndpoint As %String, pType As %String) As %String
{
    Quit ##super(pEndpoint, pType)
}

/// <p><method>Invoke</method>'s branches as a script (AD-59): a <code>DELETE</code> is the vendor call and a
/// <code>comment</code> step naming the re-read that follows an error; every other call is the admin port's
/// script. The composed read is a guard a script cannot carry.</p>
ClassMethod Snippet(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", pContext As %DynamicObject = "") As %DynamicArray
{
    Set tSteps = ##super(pEndpoint, pType, .pQuery, pBody, pContext)
    If (pEndpoint = ..#ENDPOINT) && (pType = ..#DELETETYPE) && (tSteps.%Size() > 0) Do tSteps.%Push(..Step("comment", ..#DELETENOTE))
    Quit tSteps
}

}

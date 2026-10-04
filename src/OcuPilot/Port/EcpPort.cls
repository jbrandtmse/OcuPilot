/// <p>The ECP data server tools' port (AD-51, AD-52, Story 18.20): <class>OcuPilot.Port.AdminPort</class>
/// with <code>ECP.DataServer</code>'s status change, create and delete sequenced here, and every other
/// call the admin port's own. It names no vendor class.</p>
/// <p><b>The status change</b> (<code>SERVERACTION</code>, queued, AD-26) builds its
/// <code>{Action}</code> from the query's <parameter>STATUSQUERY</parameter> through
/// <parameter>STATUSACTIONS</parameter>, in this order: a caller body is refused; a status outside the
/// three is <code>TOOL.ARGUMENTS</code>; Normal is refused 422
/// <parameter>OcuPilot.Api.EcpError.LICENSE</parameter> on <code>Status</code> while
/// <method>NetworkEnabled</method> answers 0, before any vendor call; the data server's
/// <code>LIST</code> row is read (absent: 404) and a status equal to its own is refused 422
/// <parameter>OcuPilot.Api.EcpError.STATUSSAME</parameter>; then <code>{Action}</code> is sent. Past
/// <method>AsyncTimeout</method> the change has started: success with HTTP
/// <parameter>STARTEDHTTP</parameter> and no answer. A task the vendor fails is 409
/// <parameter>OcuPilot.Api.EcpError.STATUSREFUSED</parameter>; its reason reaches the log alone. So no
/// instance whose license lacks ECP is ever sent <code>Action</code> 3.</p>
/// <p><b>A <code>PUT</code></b> that creates (its name is not on the <code>LIST</code>) is refused 409
/// <parameter>OcuPilot.Api.EcpError.SERVERLIMIT</parameter> before any vendor write once the configured
/// data servers reach <code>ECP.Settings</code>' <code>AppServerSettings.MaxServers</code>, read from
/// the instance at the call, because the vendor answers such a create 500 #456 and records a create
/// event with nothing stored. The vendor's refusal of SSL/TLS without an <code>%ECPClient</code>
/// configuration (#1454) is 422 <parameter>OcuPilot.Api.EcpError.SSLCLIENT</parameter> on
/// <code>SSLConfig</code>.</p>
/// <p><b>A <code>DELETE</code></b> the vendor refuses 409 (#423, a remote database uses the server) is
/// 409 <parameter>OcuPilot.Api.EcpError.INUSE</parameter>.</p>
/// <p><b>Caller contract:</b> every vendor call goes through <method>Call</method>, so a test port
/// overrides that one method, and <method>NetworkEnabled</method> is the license seam.</p>
Class OcuPilot.Port.EcpPort Extends OcuPilot.Port.AdminPort
{

/// <p>The data server endpoint.</p>
Parameter ENDPOINT = "ECP.DataServer";

/// <p>The ECP settings endpoint, read for the data server limit.</p>
Parameter SETTINGSENDPOINT = "ECP.Settings";

/// <p>The status change's request type.</p>
Parameter ACTIONTYPE = "SERVERACTION";

/// <p>The pairs whose body this port composes rather than takes from its caller (AD-51).</p>
Parameter COMPOSEDTYPES = "ECP.DataServer/SERVERACTION";

/// <p>The HTTP status of a status change still running when <method>AsyncTimeout</method> passes:
/// accepted, and continuing on the instance (AD-26).</p>
Parameter STARTEDHTTP = 202;

/// <p>Each status the change status tool declares and the vendor's <code>Action</code> for it.</p>
Parameter STATUSACTIONS = "notconnected:1,disabled:2,normal:3";

/// <p>Each status and the label the vendor's <code>LIST</code> answers for it on this build.</p>
Parameter STATUSLABELS = "notconnected:Not Connected,disabled:Disabled,normal:Normal";

/// <p>The status that connects, which the license must enable.</p>
Parameter NORMALSTATUS = "normal";

/// <p>The query key the change status tool's one argument travels under.</p>
Parameter STATUSQUERY = "Status";

/// <p>The vendor's body key for the action.</p>
Parameter ACTIONFIELD = "Action";

/// <p>The query parameter a data server is named by.</p>
Parameter NAMEPARAM = "name";

/// <p>The <code>LIST</code> row's name and status members.</p>
Parameter NAMEFIELD = "Name";

Parameter STATUSFIELD = "Status";

/// <p>The settings group and member that hold the data server limit.</p>
Parameter LIMITGROUP = "AppServerSettings";

Parameter LIMITFIELD = "MaxServers";

/// <p>The field the vendor's SSL/TLS refusal names.</p>
Parameter SSLFIELD = "SSLConfig";

/// <p>One vendor call: <method>OcuPilot.Port.AdminPort.Invoke</method>. Every call this port makes
/// goes through here, so a test port overrides this one method to record or answer a call.</p>
ClassMethod Call(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Quit ##class(OcuPilot.Port.AdminPort).Invoke(pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
}

/// <p>Whether this instance's license enables ECP: <method>OcuPilot.Port.RemoteDatabasePort.NetworkEnabled</method>.
/// The seam a test port overrides; production never does.</p>
ClassMethod NetworkEnabled() As %Boolean
{
    Quit ''##class(OcuPilot.Port.RemoteDatabasePort).NetworkEnabled()
}

/// <p>The admin port's call, with this class's header's branches for <parameter>ENDPOINT</parameter>.
/// A read is sent without <parameter>STATUSQUERY</parameter>, which is this port's own key.</p>
/// <p><b>Caller contract:</b> the arguments and outputs are
/// <method>OcuPilot.Port.AdminPort.Invoke</method>'s.</p>
ClassMethod Invoke(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pResult = ""
    Set pHttpStatus = 0
    Set pFault = ""
    If pEndpoint = ..#ENDPOINT {
        If pType = ..#ACTIONTYPE Quit ..ServerAction(.pQuery, pBody, .pResult, .pHttpStatus, .pFault)
        If pType = "PUT" Quit ..Put(.pQuery, pBody, .pResult, .pHttpStatus, .pFault)
        If pType = "DELETE" Quit ..Delete(.pQuery, .pResult, .pHttpStatus, .pFault)
        Merge tQuery = pQuery
        Kill tQuery(..#STATUSQUERY)
        Quit ..Call(pEndpoint, pType, .tQuery, pBody, .pResult, .pHttpStatus, .pFault)
    }
    Quit ..Call(pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
}

/// <p>The vendor's <code>Action</code> for status <var>pStatus</var>, compared without regard to case,
/// or <code>""</code> for a status outside <parameter>STATUSACTIONS</parameter>.</p>
ClassMethod ActionFor(pStatus As %String) As %String
{
    Quit ..StatusValue(..#STATUSACTIONS, $ZConvert(pStatus, "L"))
}

/// <p>The <code>LIST</code> label for status <var>pStatus</var>, or <code>""</code>.</p>
ClassMethod LabelFor(pStatus As %String) As %String
{
    Quit ..StatusValue(..#STATUSLABELS, $ZConvert(pStatus, "L"))
}

/// <p>The statuses <parameter>STATUSACTIONS</parameter> names, in its order, as a
/// <class>%List</class>: the change status tool's enum.</p>
ClassMethod Statuses() As %List
{
    Set tStatuses = ""
    For tI = 1:1:$Length(..#STATUSACTIONS, ",") {
        Set tStatuses = tStatuses _ $ListBuild($Piece($Piece(..#STATUSACTIONS, ",", tI), ":", 1))
    }
    Quit tStatuses
}

/// <p>The status change: this class's header's sequence for the data server <var>pQuery</var> names.</p>
ClassMethod ServerAction(ByRef pQuery, pBody As %DynamicAbstractObject, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    Set pHttpStatus = 0
    Set pFault = ""
    If $IsObject(pBody) || (pBody '= "") {
        Set tSC = ..Refuse(500, ##class(OcuPilot.Api.Error).#SERVERERROR, ##class(OcuPilot.Api.Error).#INTERNAL, ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON, .pHttpStatus, .pFault)
        Do ..LogFault(..#ENDPOINT _ " " _ ..#ACTIONTYPE _ " was given a caller body, and its body is built by the port", $$$ERROR($$$GeneralError, "a data server status change takes no caller body"), pFault.code)
        Quit tSC
    }
    Set tName = $Get(pQuery(..#NAMEPARAM))
    Set tStatus = $ZConvert($Get(pQuery(..#STATUSQUERY)), "L")
    Set tAction = ..ActionFor(tStatus)
    If tAction = "" {
        Set tDetail = {}
        Do tDetail.%Set("problem", "'" _ ..#STATUSQUERY _ "' is one of " _ $ListToString(..Statuses(), ", "), "string")
        Quit ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#TOOLARGUMENTS, ##class(OcuPilot.Api.Error).#REASONTOOLARGUMENTS, .pHttpStatus, .pFault, tDetail)
    }
    If (tStatus = ..#NORMALSTATUS) && '..NetworkEnabled() Quit ..Refused(..#STATUSQUERY, ##class(OcuPilot.Api.EcpError).#LICENSE, .pHttpStatus, .pFault)
    Set tSC = ..Row(tName, .tRow, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    If ..Text(tRow, ..#STATUSFIELD) = ..LabelFor(tStatus) Quit ..Refused(..#STATUSQUERY, ##class(OcuPilot.Api.EcpError).#STATUSSAME, .pHttpStatus, .pFault)
    Set pHttpStatus = 0
    Set pFault = ""
    Kill tQuery
    Set tQuery(..#NAMEPARAM) = tName
    Set tSC = ..Call(..#ENDPOINT, ..#ACTIONTYPE, .tQuery, ..ActionBody(tAction), .pResult, .pHttpStatus, .pFault)
    If $$$ISOK(tSC) Quit tSC
    ; AD-26: past the bound the queued change has started, and the vendor's worker finishes it.
    If $IsObject($Get(pFault)) && (pFault.%Get("code") = ##class(OcuPilot.Api.Error).#PORTTIMEOUT) {
        Set pResult = ""
        Set pHttpStatus = ..#STARTEDHTTP
        Set pFault = ""
        Quit $$$OK
    }
    ; A task the vendor failed: its reason was logged where the task was read.
    If +$Get(pHttpStatus) = 500 {
        Set pResult = ""
        Quit ..Refuse(409, ##class(OcuPilot.Api.Error).#CONFLICT, ##class(OcuPilot.Api.EcpError).#STATUSREFUSED, ##class(OcuPilot.Api.EcpError).#REASONSTATUSREFUSED, .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>The status change's body, <code>{Action}</code>, for the vendor action <var>pAction</var>.</p>
ClassMethod ActionBody(pAction As %Integer) As %DynamicObject
{
    Set tBody = {}
    Do tBody.%Set(..#ACTIONFIELD, +pAction, "number")
    Quit tBody
}

/// <p>The data server <var>pName</var>'s <code>LIST</code> row, matched without regard to case, in
/// <var>pRow</var>; a name the list does not hold is 404 <code>PORT.NOTFOUND</code>.</p>
ClassMethod Row(pName As %String, Output pRow As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pRow = ""
    Set tSC = ..Rows(.tRows, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Set tWanted = $ZConvert(pName, "U")
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tCandidate) {
        If '$IsObject(tCandidate) Continue
        If $ZConvert(..Text(tCandidate, ..#NAMEFIELD), "U") '= tWanted Continue
        Set pRow = tCandidate
        Quit
    }
    If $IsObject(pRow) Quit $$$OK
    Set pHttpStatus = 404
    Do ##class(OcuPilot.Kernel.Fault).Outcome(404, $$$OK, .pFault, .tDetail)
    Quit $$$ERROR($$$GeneralError, ##class(OcuPilot.Api.Error).#PORTNOTFOUND)
}

/// <p>Every data server the instance defines, as the vendor's <code>LIST</code> answers them, in
/// <var>pRows</var>; an answer that is not an array is a 500.</p>
ClassMethod Rows(Output pRows As %DynamicArray, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pRows = []
    Kill tQuery
    Set tSC = ..Call(..#ENDPOINT, "LIST", .tQuery, "", .tAnswer, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    If $IsObject($Get(tAnswer)) && tAnswer.%IsA("%Library.DynamicArray") {
        Set pRows = tAnswer
        Quit $$$OK
    }
    Set tSC = ..Refuse(500, ##class(OcuPilot.Api.Error).#SERVERERROR, ##class(OcuPilot.Api.Error).#INTERNAL, ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON, .pHttpStatus, .pFault)
    Do ..LogFault(..#ENDPOINT _ " LIST answered no array", $$$ERROR($$$GeneralError, "the data server list is not an array"), pFault.code)
    Quit tSC
}

/// <p>The data server limit, <code>ECP.Settings</code>' <parameter>LIMITGROUP</parameter>
/// <parameter>LIMITFIELD</parameter> as the caller reads it now, in <var>pMaximum</var>; an answer
/// without a whole number there is a 500.</p>
ClassMethod MaxServers(Output pMaximum As %Integer, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pMaximum = ""
    Kill tQuery
    Set tSC = ..Call(..#SETTINGSENDPOINT, "GET", .tQuery, "", .tSettings, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Set tGroup = ""
    If $IsObject($Get(tSettings)) && tSettings.%IsA("%Library.DynamicObject") && (tSettings.%GetTypeOf(..#LIMITGROUP) = "object") Set tGroup = tSettings.%Get(..#LIMITGROUP)
    If $IsObject(tGroup) && $Match(tGroup.%Get(..#LIMITFIELD) _ "", "[0-9]{1,5}") {
        Set pMaximum = +tGroup.%Get(..#LIMITFIELD)
        Quit $$$OK
    }
    Set tSC = ..Refuse(500, ##class(OcuPilot.Api.Error).#SERVERERROR, ##class(OcuPilot.Api.Error).#INTERNAL, ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON, .pHttpStatus, .pFault)
    Do ..LogFault(..#SETTINGSENDPOINT _ " GET answered no data server limit", $$$ERROR($$$GeneralError, "the ECP settings carry no whole-number " _ ..#LIMITGROUP _ "." _ ..#LIMITFIELD), pFault.code)
    Quit tSC
}

/// <p>A data server's <code>PUT</code>: a create past the limit refused, then the vendor's
/// <code>PUT</code>, whose SSL/TLS refusal is answered on its field.</p>
ClassMethod Put(ByRef pQuery, pBody As %DynamicAbstractObject, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Set tSC = ..Rows(.tRows, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Set tWanted = $ZConvert($Get(pQuery(..#NAMEPARAM)), "U")
    Set tCount = 0
    Set tHeld = 0
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If '$IsObject(tRow) Continue
        Set tCount = tCount + 1
        If $ZConvert(..Text(tRow, ..#NAMEFIELD), "U") = tWanted Set tHeld = 1
    }
    If 'tHeld {
        Set tSC = ..MaxServers(.tMaximum, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit tSC
        If tCount >= tMaximum {
            Quit ..Refuse(409, ##class(OcuPilot.Api.Error).#CONFLICT, ##class(OcuPilot.Api.EcpError).#SERVERLIMIT, ##class(OcuPilot.Api.EcpError).Limit(tMaximum), .pHttpStatus, .pFault)
        }
    }
    Set pHttpStatus = 0
    Set pFault = ""
    Merge tQuery = pQuery
    Kill tQuery(..#STATUSQUERY)
    Set tSC = ..Call(..#ENDPOINT, "PUT", .tQuery, pBody, .pResult, .pHttpStatus, .pFault)
    If $$$ISOK(tSC) Quit tSC
    If ..Violates(pFault, ##class(OcuPilot.Api.EcpError).#SSLCLIENT) {
        Set pResult = ""
        Quit ..Refused(..#SSLFIELD, ##class(OcuPilot.Api.EcpError).#SSLCLIENT, .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>A data server's <code>DELETE</code>: the vendor's 409 answered
/// <parameter>OcuPilot.Api.EcpError.INUSE</parameter>.</p>
ClassMethod Delete(ByRef pQuery, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Merge tQuery = pQuery
    Kill tQuery(..#STATUSQUERY)
    Set tSC = ..Call(..#ENDPOINT, "DELETE", .tQuery, "", .pResult, .pHttpStatus, .pFault)
    If $$$ISOK(tSC) Quit tSC
    If +$Get(pHttpStatus) = 409 {
        Set pResult = ""
        Quit ..Refuse(409, ##class(OcuPilot.Api.Error).#CONFLICT, ##class(OcuPilot.Api.EcpError).#INUSE, ##class(OcuPilot.Api.EcpError).#REASONINUSE, .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>Whether <var>pFault</var>'s <code>detail.violations</code> carries the code <var>pCode</var>.</p>
ClassMethod Violates(pFault As %DynamicObject, pCode As %String) As %Boolean [ Private ]
{
    If '$IsObject($Get(pFault)) || (pFault.%GetTypeOf("detail") '= "object") Quit 0
    Set tDetail = pFault.%Get("detail")
    If tDetail.%GetTypeOf("violations") '= "array" Quit 0
    Set tFound = 0
    Set tIterator = tDetail.%Get("violations").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If $IsObject(tRow) && (tRow.%Get("code") = pCode) Set tFound = 1
    }
    Quit tFound
}

/// <p>A 422 refusal whose one violation names <var>pField</var> with <var>pCode</var> and its sentence,
/// the envelope carrying the same code, with nothing sent.</p>
ClassMethod Refused(pField As %String, pCode As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tReason = ##class(OcuPilot.Api.EcpError).ReasonFor(pCode)
    Set pHttpStatus = 422
    Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#VALIDATIONFAILED, pCode, tReason)
    Set tViolation = {}
    Do tViolation.%Set("field", pField, "string")
    Do tViolation.%Set("code", pCode, "string")
    Do tViolation.%Set("reason", tReason, "string")
    Do pFault.%Set("detail", {"violations": [(tViolation)]})
    Quit $$$ERROR($$$GeneralError, pCode)
}

/// <p>The value <var>pList</var>, comma-separated <code>key:value</code> pairs, holds for
/// <var>pKey</var>, or <code>""</code>.</p>
ClassMethod StatusValue(pList As %String, pKey As %String) As %String [ Private ]
{
    If pKey = "" Quit ""
    For tI = 1:1:$Length(pList, ",") {
        Set tPair = $Piece(pList, ",", tI)
        If $Piece(tPair, ":", 1) = pKey Quit
        Set tPair = ""
    }
    Quit $Piece($Get(tPair), ":", 2, *)
}

/// <p><var>pObject</var>'s <var>pField</var> as text: absent, null, an object or an array as
/// <code>""</code>.</p>
ClassMethod Text(pObject, pField As %String) As %String [ Private ]
{
    If '$IsObject(pObject) || 'pObject.%IsA("%Library.DynamicObject") Quit ""
    Set tType = pObject.%GetTypeOf(pField)
    If (tType = "unassigned") || (tType = "null") || (tType = "object") || (tType = "array") Quit ""
    Quit pObject.%Get(pField) _ ""
}

/// <p>The admin port's answer: each branch is the vendor's own routes.</p>
ClassMethod SnippetForm(pEndpoint As %String, pType As %String) As %String
{
    Quit ##super(pEndpoint, pType)
}

/// <p><method>Invoke</method>'s branches as a script (AD-59): a status change is one
/// <code>rest</code> step, <code>POST</code> of the vendor's action route for the data server with
/// <code>{Action}</code>, except Normal on an instance whose license enables no ECP, which renders no
/// call and one <code>comment</code> step carrying the license sentence, as <method>Invoke</method>
/// refuses it; a <code>PUT</code>, a <code>DELETE</code> and every other call are the admin port's
/// script. The list read, the limit and the same-status check are guards a script cannot carry.</p>
ClassMethod Snippet(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", pContext As %DynamicObject = "") As %DynamicArray
{
    If (pEndpoint = ..#ENDPOINT) && (pType = ..#ACTIONTYPE) {
        Set tStatus = $ZConvert($Get(pQuery(..#STATUSQUERY)), "L")
        Set tAction = ..ActionFor(tStatus)
        If tAction = "" Quit []
        If (tStatus = ..#NORMALSTATUS) && '..NetworkEnabled() Quit [(..Step("comment", ##class(OcuPilot.Api.EcpError).#REASONLICENSE))]
        Kill tQuery
        Set tQuery(..#NAMEPARAM) = $Get(pQuery(..#NAMEPARAM))
        Set tStep = ..RestStep(..#ENDPOINT, ..#ACTIONTYPE, .tQuery, ..ActionBody(tAction), pContext)
        If '$IsObject(tStep) Quit []
        Quit [(tStep)]
    }
    If pEndpoint = ..#ENDPOINT {
        Merge tQuery = pQuery
        Kill tQuery(..#STATUSQUERY)
        Quit ##super(pEndpoint, pType, .tQuery, pBody, pContext)
    }
    Quit ##super(pEndpoint, pType, .pQuery, pBody, pContext)
}

}

/// <p>The superservers' port (AD-27, AD-52, Story 18.25): <class>OcuPilot.Port.AdminPort</class> with two
/// things added on <code>Security.Superserver</code>, and every other call the admin port's own,
/// unchanged. It names no vendor class.</p>
/// <p><b>A superserver's composite id is split here.</b> The vendor addresses one superserver by the
/// <code>port</code> and <code>bindAddress</code> query parameters, while the product carries one id,
/// <code>[Port, BindAddress]</code> joined by <method>OcuPilot.Kernel.EntityId.JoinComposite</method>, under
/// <code>port</code>. A <code>GET</code>, <code>PUT</code> or <code>DELETE</code> whose query carries no
/// <code>bindAddress</code> has that id split; one that carries it, and every <code>LIST</code>, passes
/// through unchanged. An id whose port is not a whole number, or that has more than two parts, names no
/// superserver: 404 <code>PORT.NOTFOUND</code>, and the vendor is not called.</p>
/// <p><b>A taken port is answered on its field.</b> The vendor refuses a write that would start a listener on
/// a port another process holds with a 500 <code>#5001</code>, which <code>OcuPilot.Port.AdminPort</code>'s
/// <code>PROPERTYFAULTS</code> maps to <parameter>OcuPilot.Api.SuperserverError.INUSE</parameter>. The code
/// is also the vendor's for its internal faults, so the mapping holds only for a write that would start a
/// listener: a create, or <code>Enabled</code> turned on where the stored one is off. Any other
/// <code>#5001</code> is the fault as it is. The admin port has logged each.</p>
/// <p><b>Caller contract:</b> every vendor call goes through <method>Call</method>, so a test port overrides
/// that one method.</p>
Class OcuPilot.Port.SuperserverPort Extends OcuPilot.Port.AdminPort
{

/// <p>The endpoint this port splits ids for.</p>
Parameter ENDPOINT = "Security.Superserver";

/// <p>The read type that lists, which carries no id.</p>
Parameter LISTTYPE = "LIST";

/// <p>The query key the caller's composite id travels under, and the vendor's own two keys.</p>
Parameter IDQUERY = "port";

Parameter BINDPARAM = "bindAddress";

/// <p>The members the stored row and a body carry that this port reads.</p>
Parameter ENABLEDFIELD = "Enabled";

/// <p>The vendor's fault code that names a taken port, as the admin port's mapping leaves it.</p>
Parameter TAKENCODE = "SUPERSERVER.PORT.INUSE";

/// <p>One vendor call: <method>OcuPilot.Port.AdminPort.Invoke</method>. Every call this port makes goes
/// through here.</p>
ClassMethod Call(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Quit ##class(OcuPilot.Port.AdminPort).Invoke(pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
}

/// <p>The admin port's call, with a superserver's composite id split and a taken port answered.</p>
/// <p><b>Caller contract:</b> the arguments and outputs are <method>OcuPilot.Port.AdminPort.Invoke</method>'s.
/// For a <code>GET</code>, <code>PUT</code> or <code>DELETE</code> on <parameter>ENDPOINT</parameter> whose
/// query carries no <code>bindAddress</code>, <code>port</code> is the composite id; a malformed one is 404
/// <code>PORT.NOTFOUND</code> with no vendor call. A <code>PUT</code> the vendor refuses for a taken port is
/// 409 <parameter>OcuPilot.Api.SuperserverError.INUSE</parameter> on <code>Port</code>; a <code>GET</code> or
/// <code>DELETE</code> refused with the same code keeps the vendor's fault without the mapped row.</p>
ClassMethod Invoke(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pResult = ""
    Set pHttpStatus = 0
    Set pFault = ""
    If (pEndpoint '= ..#ENDPOINT) || (pType = ..#LISTTYPE) Quit ..Call(pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
    If $Data(pQuery(..#BINDPARAM)) # 2 {
        Merge tQuery = pQuery
    } ElseIf '..SplitId(.pQuery, .tQuery) {
        Quit ..Fail(pEndpoint, 404, $$$OK, .pHttpStatus, .pFault)
    }
    If pType = "PUT" Quit ..Put(.tQuery, pBody, .pResult, .pHttpStatus, .pFault)
    Set tSC = ..Call(pEndpoint, pType, .tQuery, pBody, .pResult, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) && ..Taken(pFault) Do pFault.%Remove("detail")
    Quit tSC
}

/// <p>A superserver's <code>PUT</code>, whose refusal for a taken port is answered 409 when the write would
/// start a listener (<method>StartsListener</method>) and otherwise left as the vendor's own fault, without
/// the mapped row.</p>
ClassMethod Put(ByRef pQuery, pBody As %DynamicAbstractObject, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tSC = ..Call(..#ENDPOINT, "PUT", .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
    If $$$ISOK(tSC) || '..Taken(pFault) Quit tSC
    If '..StartsListener(.pQuery, pBody) {
        If $IsObject(pFault) Do pFault.%Remove("detail")
        Quit tSC
    }
    Set pResult = ""
    Set tViolation = {}
    Do tViolation.%Set("field", "Port", "string")
    Do tViolation.%Set("code", ..#TAKENCODE, "string")
    Do tViolation.%Set("reason", ##class(OcuPilot.Api.SuperserverError).#REASONINUSE, "string")
    Quit ..Refuse(409, ##class(OcuPilot.Api.Error).#CONFLICT, ..#TAKENCODE, ##class(OcuPilot.Api.SuperserverError).#REASONINUSE, .pHttpStatus, .pFault, {"violations": [(tViolation)]})
}

/// <p>Whether <var>pFault</var> carries the mapped taken-port violation.</p>
ClassMethod Taken(pFault As %DynamicObject) As %Boolean [ Private ]
{
    If '$IsObject($Get(pFault)) || (pFault.%GetTypeOf("detail") '= "object") Quit 0
    Set tRows = pFault.%Get("detail").%Get("violations")
    If '$IsObject(tRows) Quit 0
    Set tFound = 0
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If $IsObject(tRow) && (tRow.%Get("code") = ..#TAKENCODE) Set tFound = 1
    }
    Quit tFound
}

/// <p>Whether the <code>PUT</code> of <var>pBody</var> to the superserver <var>pQuery</var> names would start
/// a listener: the superserver is absent, so the write creates it, or its stored <code>Enabled</code> is off
/// and the body turns it on. A stored row that cannot be read answers 0.</p>
ClassMethod StartsListener(ByRef pQuery, pBody As %DynamicAbstractObject) As %Boolean
{
    Merge tQuery = pQuery
    Set tSC = ..Call(..#ENDPOINT, "GET", .tQuery, "", .tStored, .tHttp, .tFault)
    If $$$ISERR(tSC) Quit (+$Get(tHttp) = 404)
    If '$IsObject($Get(tStored)) || 'tStored.%IsA("%Library.DynamicObject") Quit 0
    If '$IsObject(pBody) || 'pBody.%IsA("%Library.DynamicObject") Quit 0
    If pBody.%GetTypeOf(..#ENABLEDFIELD) = "unassigned" Quit 0
    Quit ..On(pBody, ..#ENABLEDFIELD) && '..On(tStored, ..#ENABLEDFIELD)
}

/// <p>Whether <var>pObject</var> carries <var>pField</var> as on: the JSON boolean true, or 1.</p>
ClassMethod On(pObject As %DynamicObject, pField As %String) As %Boolean [ Private ]
{
    Set tType = pObject.%GetTypeOf(pField)
    If (tType = "unassigned") || (tType = "null") || (tType = "object") || (tType = "array") Quit 0
    Set tValue = pObject.%Get(pField)
    Quit (tValue = 1) || ($ZConvert(tValue, "L") = "true")
}

/// <p>A copy of <var>pQuery</var> in <var>pSplit</var> with its composite <code>port</code> split into the
/// vendor's whole-number <code>port</code> and, when the id carries one, <code>bindAddress</code>; 0 when the
/// id has more than two parts or its port is not a whole number of at most five digits.</p>
ClassMethod SplitId(ByRef pQuery, Output pSplit) As %Boolean
{
    Kill pSplit
    Merge pSplit = pQuery
    Set tParts = ##class(OcuPilot.Kernel.EntityId).SplitComposite($Get(pQuery(..#IDQUERY)))
    If ($ListLength(tParts) < 1) || ($ListLength(tParts) > 2) Quit 0
    Set tPort = $ListGet(tParts, 1)
    If '$Match(tPort, "[0-9]{1,5}") Quit 0
    Set pSplit(..#IDQUERY) = +tPort
    Set tBind = $ListGet(tParts, 2)
    If tBind '= "" Set pSplit(..#BINDPARAM) = tBind
    Quit 1
}

/// <p>The admin port's answer: this port's calls are the vendor's own routes.</p>
ClassMethod SnippetForm(pEndpoint As %String, pType As %String) As %String
{
    Quit ##super(pEndpoint, pType)
}

/// <p><method>Invoke</method>'s branches as a script (AD-59): a call on <parameter>ENDPOINT</parameter> whose
/// query carries no <code>bindAddress</code> is the vendor call with the split query, and a malformed id
/// answers no step; every other call is the admin port's script. The taken-port answer is a response, not a
/// call, and adds no step.</p>
ClassMethod Snippet(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", pContext As %DynamicObject = "") As %DynamicArray
{
    If (pEndpoint = ..#ENDPOINT) && (pType '= ..#LISTTYPE) && '($Data(pQuery(..#BINDPARAM)) # 2) {
        If '..SplitId(.pQuery, .tQuery) Quit []
        Quit ##super(pEndpoint, pType, .tQuery, pBody, pContext)
    }
    Quit ##super(pEndpoint, pType, .pQuery, pBody, pContext)
}

}

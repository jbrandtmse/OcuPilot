/// <p>The percent-class access port (AD-27, AD-52, Story 18.10): <class>OcuPilot.Port.AdminPort</class> with
/// <code>WebApp.PctClassAccess</code> composed, and every other call the admin port's own, unchanged. It names no
/// vendor class.</p>
/// <p><b>One entry's id is split here.</b> The product carries one id, <code>[Name, AllowType, Class]</code>, joined
/// by <class>OcuPilot.Kernel.EntityId</class>, under <code>name</code>; the vendor addresses an entry by three query
/// parameters. A <code>GET</code>, <code>PUT</code> or <code>DELETE</code> is split and its shape checked before the
/// vendor is called (<method>Shape</method>). A <code>LIST</code> passes through.</p>
/// <p><b>Two composed reads and a refusal.</b> <parameter>STATE</parameter> answers the one entry as
/// <code>{AllowAccess, System}</code> or 404, read from the list. A <code>DELETE</code> of an entry the instance
/// marks as its own (<code>System</code>) is refused 409 <code>PCTACCESS.SYSTEM</code> before the vendor, since such an
/// entry goes only with its application.</p>
/// <p><b>Caller contract:</b> every vendor call goes through <method>Call</method>.</p>
Class OcuPilot.Port.PctAccessPort Extends OcuPilot.Port.AdminPort
{

/// <p>The endpoint this port splits ids for.</p>
Parameter ENDPOINT = "WebApp.PctClassAccess";

/// <p>The read type that lists, which carries no id.</p>
Parameter LISTTYPE = "LIST";

/// <p>The read type that answers one entry's state from the list (AD-51).</p>
Parameter STATE = "STATE";

/// <p>The query key the caller's composite id travels under.</p>
Parameter IDQUERY = "name";

/// <p>The vendor's three keys for one entry.</p>
Parameter NAMEKEY = "name";

Parameter ALLOWTYPEKEY = "allowType";

Parameter CLASSKEY = "class";

/// <p>The two access types the instance accepts.</p>
Parameter ALLOWTYPES = "AllowClass,AllowPrefix";

/// <p>The class or package name shape: a percent sign, then letters, digits and dots.</p>
Parameter CLASSPATTERN = "^%[A-Za-z0-9][A-Za-z0-9.]{0,254}$";

/// <p>The application name the instance accepts for all applications.</p>
Parameter ALLAPPLICATIONS = "all-applications";

/// <p>The application endpoint whose <code>GET</code> confirms a named application exists.</p>
Parameter APPENDPOINT = "WebApp.App";

/// <p>The vendor's <code>System</code> flag, which the list answers as a boolean.</p>
Parameter SYSTEMFIELD = "System";

/// <p>The one call this port makes to the vendor. Every call this port makes goes through here.</p>
ClassMethod Call(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Quit ##class(OcuPilot.Port.AdminPort).Invoke(pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
}

/// <p>The admin port's call, with <parameter>STATE</parameter> answered and one entry's composite id split and
/// checked. Any shape refusal is answered here, before the vendor.</p>
/// <p><b>Caller contract:</b> the arguments and outputs are <method>OcuPilot.Port.AdminPort.Invoke</method>'s.</p>
ClassMethod Invoke(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pResult = ""
    Set pHttpStatus = 0
    Set pFault = ""
    If (pEndpoint '= ..#ENDPOINT) || (pType = ..#LISTTYPE) Quit ..Call(pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
    If pType = ..#STATE Quit ..State(.pQuery, .pResult, .pHttpStatus, .pFault)
    Set tSC = ..Shape(.pQuery, .tSplit, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) || (pHttpStatus '= 0) Quit tSC
    If pType = "DELETE" {
        Set tSC = ..RefuseSystem(.tSplit, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) || (pHttpStatus '= 0) Quit tSC
    }
    Quit ..Call(pEndpoint, pType, .tSplit, pBody, .pResult, .pHttpStatus, .pFault)
}

/// <p>Splits the composite <code>name</code> of <var>pQuery</var> into the vendor's three keys in <var>pSplit</var>,
/// and checks the shape: the allow type, the class name, and the application (a trailing slash, or an application
/// the instance does not hold, is refused). A refusal sets <var>pHttpStatus</var> to 422 with no vendor call.</p>
/// <p><b>Caller contract:</b> <var>pHttpStatus</var> is 0 when the shape passes.</p>
ClassMethod Shape(ByRef pQuery, Output pSplit, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pHttpStatus = 0
    Set pFault = ""
    Kill pSplit
    Set tParts = ##class(OcuPilot.Kernel.EntityId).SplitComposite($Get(pQuery(..#IDQUERY)))
    If ($ListLength(tParts) '= 3) Quit ..Unprocessable(##class(OcuPilot.Api.PctAccessError).#BADID, ##class(OcuPilot.Api.PctAccessError).#REASONBADID, .pHttpStatus, .pFault)
    Set tName = $ListGet(tParts, 1)
    Set tAllowType = $ListGet(tParts, 2)
    Set tClass = $ListGet(tParts, 3)
    If '$ListFind($ListFromString(..#ALLOWTYPES), tAllowType) Quit ..Unprocessable(##class(OcuPilot.Api.PctAccessError).#ALLOWTYPE, ##class(OcuPilot.Api.PctAccessError).#REASONALLOWTYPE, .pHttpStatus, .pFault)
    If '$Match(tClass, ..#CLASSPATTERN) Quit ..Unprocessable(##class(OcuPilot.Api.PctAccessError).#CLASS, ##class(OcuPilot.Api.PctAccessError).#REASONCLASS, .pHttpStatus, .pFault)
    If (tName = "") || ($Extract(tName, *) = "/") || ((tName '= ..#ALLAPPLICATIONS) && '..ApplicationHeld(tName)) {
        Quit ..Unprocessable(##class(OcuPilot.Api.PctAccessError).#APPLICATION, ##class(OcuPilot.Api.PctAccessError).#REASONAPPLICATION, .pHttpStatus, .pFault)
    }
    Set pSplit(..#NAMEKEY) = tName
    Set pSplit(..#ALLOWTYPEKEY) = tAllowType
    Set pSplit(..#CLASSKEY) = tClass
    Quit $$$OK
}

/// <p>Whether the instance holds the web application <var>pName</var>, by the vendor's own <code>GET</code>; an
/// absent name is 404, and any other failure answers 0 as well, so the shape refusal stays the answer.</p>
ClassMethod ApplicationHeld(pName As %String) As %Boolean [ Private ]
{
    Kill tQuery
    Set tQuery(..#NAMEKEY) = pName
    Set tSC = ..Call(..#APPENDPOINT, "GET", .tQuery, "", .tRead, .tHttp, .tFault)
    Quit $$$ISOK(tSC)
}

/// <p>Refuses 422 with <var>pCode</var> and the sentence <var>pReason</var>, with no vendor call.</p>
ClassMethod Unprocessable(pCode As %String, pReason As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Quit ..Refuse(422, ##class(OcuPilot.Api.Error).#BADREQUEST, pCode, pReason, .pHttpStatus, .pFault)
}

/// <p>Refuses 409 <code>PCTACCESS.SYSTEM</code> when the entry <var>pSplit</var> names is the instance's own, read from
/// the list; an entry the list does not hold passes, and the vendor answers its own 404.</p>
ClassMethod RefuseSystem(ByRef pSplit, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pHttpStatus = 0
    Set pFault = ""
    Set tSC = ..Entry(.pSplit, .tEntry)
    If $$$ISERR(tSC) Quit tSC
    If $IsObject(tEntry) && (tEntry.%Get(..#SYSTEMFIELD) = 1) {
        Quit ..Refuse(409, ##class(OcuPilot.Api.Error).#CONFLICT, ##class(OcuPilot.Api.PctAccessError).#SYSTEM, ##class(OcuPilot.Api.PctAccessError).#REASONSYSTEM, .pHttpStatus, .pFault)
    }
    Quit $$$OK
}

/// <p>The list row for the entry <var>pSplit</var> names: the name in any letter case, the allow type and the class
/// exactly. <var>pEntry</var> is the row as a <class>%DynamicObject</class>, or <code>""</code> when none matches.</p>
ClassMethod Entry(ByRef pSplit, Output pEntry As %DynamicObject) As %Status [ Private ]
{
    Set pEntry = ""
    Kill tList
    Set tList("names") = $Get(pSplit(..#NAMEKEY))
    Set tSC = ..Call(..#ENDPOINT, ..#LISTTYPE, .tList, "", .tRows, .tHttp, .tFault)
    If $$$ISERR(tSC) Quit tSC
    If '$IsObject($Get(tRows)) Quit $$$OK
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If '$IsObject(tRow) Continue
        If ($ZConvert(tRow.%Get("Name"), "L") = $ZConvert($Get(pSplit(..#NAMEKEY)), "L")) && (tRow.%Get("AllowType") = $Get(pSplit(..#ALLOWTYPEKEY))) && (tRow.%Get("Class") = $Get(pSplit(..#CLASSKEY))) {
            Set pEntry = tRow
            Quit
        }
    }
    Quit $$$OK
}

/// <p>The state of one entry, <parameter>STATE</parameter> (AD-51): <code>{AllowAccess, System}</code> from the list,
/// or 404 when the list holds no such entry. The composite id is read as <code>name</code>, unsplit.</p>
ClassMethod State(ByRef pQuery, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Set tSC = ..Shape(.pQuery, .tSplit, .tShapeHttp, .tShapeFault)
    If $$$ISERR(tSC) || (tShapeHttp '= 0) {
        Set pHttpStatus = tShapeHttp
        Set pFault = tShapeFault
        Quit tSC
    }
    Set tSC = ..Entry(.tSplit, .tEntry)
    If $$$ISERR(tSC) Quit tSC
    If '$IsObject(tEntry) {
        Set pHttpStatus = 404
        Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#NOTFOUND, ##class(OcuPilot.Api.PctAccessError).#NOTFOUND, ##class(OcuPilot.Api.PctAccessError).#REASONNOTFOUND)
        Quit $$$ERROR($$$GeneralError, ##class(OcuPilot.Api.PctAccessError).#NOTFOUND)
    }
    Set pResult = {"AllowAccess": (tEntry.%Get("AllowAccess")), "System": (tEntry.%Get(..#SYSTEMFIELD))}
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>The sentence an instance-owned entry's refusal carries (AD-39), read by the entry's delete tool's
/// <method>StateDiff</method> so the tool names no API class.</p>
ClassMethod SystemReason() As %String
{
    Quit ##class(OcuPilot.Api.PctAccessError).#REASONSYSTEM
}

/// <p>The admin port's answer: this port's calls are the vendor's own routes.</p>
ClassMethod SnippetForm(pEndpoint As %String, pType As %String) As %String
{
    Quit ##super(pEndpoint, pType)
}

/// <p><method>Invoke</method>'s vendor call as a script (AD-59): a <code>GET</code>, <code>PUT</code> or
/// <code>DELETE</code> on <parameter>ENDPOINT</parameter> is the vendor call with the split query, and a malformed id
/// answers no step. The shape and system checks are guards a script cannot carry and add no step.</p>
ClassMethod Snippet(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", pContext As %DynamicObject = "") As %DynamicArray
{
    If (pEndpoint = ..#ENDPOINT) && (pType '= ..#LISTTYPE) && (pType '= ..#STATE) {
        Set tSC = ..Shape(.pQuery, .tSplit, .tHttp, .tFault)
        If $$$ISERR(tSC) || (tHttp '= 0) Quit []
        Quit ##super(pEndpoint, pType, .tSplit, pBody, pContext)
    }
    Quit ##super(pEndpoint, pType, .pQuery, pBody, pContext)
}

}

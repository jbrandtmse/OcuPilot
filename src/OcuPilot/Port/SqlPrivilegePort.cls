/// <p>The SQL object privileges' port (AD-27, AD-52, Story 18.9): <class>OcuPilot.Port.AdminPort</class> with
/// four request types composed on <code>Security.SQLPrivilege.Standard</code>, and every other call the admin
/// port's own, unchanged. It names no vendor class.</p>
/// <p><b>Two composed reads.</b> <parameter>GRANTSTATE</parameter> and <parameter>REVOKESTATE</parameter> answer
/// <code>{Namespace, Type, Object, Action, [WithGrant], Held, GrantOption, GrantedBy, Rows}</code> from one
/// <code>LIST</code> (<code>includeSystem</code> 1, <parameter>MAXROWS</parameter> rows, a full answer a fault).
/// Outside a schema, <code>Rows</code> counts the grantee's <code>Direct</code> rows for the object and action
/// (a table and a view alike) and <code>GrantedBy</code> names their distinct grantors, sorted and comma-joined;
/// for a schema they are the <code>Schema Privilege</code> rows of the schema's objects for the action. They refuse,
/// before any vendor call and in this order: the Rules (422 <code>SQLPRIV.VALIDATION</code>, each violation
/// naming its field), a grantee holding <code>%All</code> (409 <code>SQLPRIV.SUPERUSER</code>), then a grant of
/// what is already held with the grant option asked for or more (409 <code>SQLPRIV.HELD</code>) and a revoke
/// with no direct row (409 <code>SQLPRIV.NOTHELD</code>).</p>
/// <p><b>A write is judged by a re-read.</b> The vendor answers a grant or revoke that moved nothing with 200.
/// <parameter>GRANT</parameter> reads the state, sends one vendor <code>GRANT</code> and reads again;
/// <parameter>REVOKE</parameter> sends one vendor <code>REVOKE</code> per grantor the read names, each with
/// <code>asGrantor</code> and <code>cascade</code> 0, and reads again. A state the write did not move is 409
/// <code>SQLPRIV.NOTAPPLIED</code>.</p>
/// <p><b>Caller contract:</b> every vendor call goes through <method>Call</method>, so a test port overrides that
/// one method. The query keys are the vendor's own: <code>grantee</code>, <code>namespace</code>,
/// <code>type</code>, <code>object</code>, <code>action</code> and, on a grant, <code>withGrant</code>.</p>
Class OcuPilot.Port.SqlPrivilegePort Extends OcuPilot.Port.AdminPort
{

/// <p>The endpoint this port composes on.</p>
Parameter ENDPOINT = "Security.SQLPrivilege.Standard";

/// <p>The composed reads and the writes this port carries out, and the vendor request type it lists with.</p>
Parameter GRANTSTATE = "GRANTSTATE";

Parameter REVOKESTATE = "REVOKESTATE";

Parameter GRANT = "GRANT";

Parameter REVOKE = "REVOKE";

Parameter LISTTYPE = "LIST";

/// <p>The pairs this port composes (AD-52): the two reads, and the two writes, each of which reads the state and
/// sends its own vendor calls.</p>
Parameter COMPOSEDTYPES = "Security.SQLPrivilege.Standard/GRANTSTATE,Security.SQLPrivilege.Standard/REVOKESTATE,Security.SQLPrivilege.Standard/GRANT,Security.SQLPrivilege.Standard/REVOKE";

/// <p>The most rows the list is asked for. A list that fills it may have been cut, which is a fault.</p>
Parameter MAXROWS = 100000;

/// <p>The query keys.</p>
Parameter GRANTEEKEY = "grantee";

Parameter NAMESPACEKEY = "namespace";

Parameter TYPEKEY = "type";

Parameter OBJECTKEY = "object";

Parameter ACTIONKEY = "action";

Parameter WITHGRANTKEY = "withGrant";

Parameter ASGRANTORKEY = "asGrantor";

/// <p>The member of a listed row that says how the grantee holds the privilege, and its values.</p>
Parameter VIAFIELD = "GrantedVia";

Parameter VIADIRECT = "Direct";

Parameter VIASCHEMA = "Schema Privilege";

Parameter VIASUPERUSER = "SuperUser";

/// <p>The six types, comma-separated, and the actions each takes (<method>ActionsFor</method>).</p>
Parameter TYPES = "TABLE,VIEW,SCHEMA,STORED PROCEDURE,ML CONFIGURATION,FOREIGN SERVER";

Parameter TABLEACTIONS = "%ALTER,SELECT,INSERT,UPDATE,DELETE,REFERENCES";

Parameter VIEWACTIONS = "%ALTER,SELECT,INSERT,UPDATE,DELETE";

Parameter SCHEMAACTIONS = "%ALTER,SELECT,INSERT,UPDATE,DELETE,REFERENCES,EXECUTE";

/// <p>The shape of one part of an object name.</p>
Parameter NAMEPATTERN = "^[%A-Za-z][A-Za-z0-9_@#$]{0,127}$";

/// <p>The label every card row carries.</p>
Parameter STATELABEL = "Privilege";

/// <p>One vendor call: <method>OcuPilot.Port.AdminPort.Invoke</method>. Every call this port makes goes through
/// here.</p>
ClassMethod Call(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Quit ##class(OcuPilot.Port.AdminPort).Invoke(pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
}

/// <p>The admin port's call, with <parameter>GRANTSTATE</parameter>, <parameter>REVOKESTATE</parameter>,
/// <parameter>GRANT</parameter> and <parameter>REVOKE</parameter> composed on <parameter>ENDPOINT</parameter>.</p>
ClassMethod Invoke(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    If pEndpoint '= ..#ENDPOINT Quit ..Call(pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
    If (pType = ..#GRANTSTATE) || (pType = ..#REVOKESTATE) Quit ..State(pType, .pQuery, .pResult, .pHttpStatus, .pFault)
    If pType = ..#GRANT Quit ..Grant(.pQuery, .pResult, .pHttpStatus, .pFault)
    If pType = ..#REVOKE Quit ..Revoke(.pQuery, .pResult, .pHttpStatus, .pFault)
    Quit ..Call(pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
}

/// <p>The actions a privilege on <var>pType</var> takes, as a <class>%List</class>; <code>""</code> for a type
/// outside <parameter>TYPES</parameter>. <code>%ALTER</code> is spelled as the instance lists it.</p>
ClassMethod ActionsFor(pType As %String) As %List
{
    If pType = "TABLE" Quit $ListFromString(..#TABLEACTIONS)
    If pType = "VIEW" Quit $ListFromString(..#VIEWACTIONS)
    If pType = "SCHEMA" Quit $ListFromString(..#SCHEMAACTIONS)
    If pType = "STORED PROCEDURE" Quit $ListBuild("EXECUTE")
    If (pType = "ML CONFIGURATION") || (pType = "FOREIGN SERVER") Quit $ListBuild("USE")
    Quit ""
}

/// <p>Whether <var>pObject</var> is a well-formed name for <var>pType</var>: one name for a schema or an ML
/// configuration, <code>schema.name</code> for every other type, each part matching
/// <parameter>NAMEPATTERN</parameter>. A type outside <parameter>TYPES</parameter> admits one name or two.</p>
ClassMethod ObjectValid(pType As %String, pObject As %String) As %Boolean
{
    Set tParts = $Length(pObject, ".")
    If (pType = "SCHEMA") || (pType = "ML CONFIGURATION") {
        If tParts '= 1 Quit 0
    } ElseIf $ListFind($ListFromString(..#TYPES), pType) {
        If tParts '= 2 Quit 0
    } ElseIf tParts > 2 {
        Quit 0
    }
    Set tValid = 1
    For tI = 1:1:tParts {
        If '$Match($Piece(pObject, ".", tI), ..#NAMEPATTERN) Set tValid = 0
    }
    Quit tValid
}

/// <p>The Rules (Story 18.9) over the query <var>pQuery</var>, as the violation codes that refuse it, in
/// <var>pCodes</var> as a <class>%List</class> without repeats: a namespace this instance does not define; a
/// grantee that is empty, over <parameter>OcuPilot.Api.SqlPrivilegeError.GRANTEEMAX</parameter> characters, or
/// carries <code>*</code> or a comma; a type outside <parameter>TYPES</parameter>; an object that is not a
/// well-formed name for its type; an action its type does not take; and, for a grant, a grant option that is not
/// boolean. A revoke (<var>pRevoke</var> 1) is not asked of the grant option.</p>
ClassMethod Violations(ByRef pQuery, pRevoke As %Boolean = 0) As %List
{
    Set tCodes = ""
    Set tType = $Get(pQuery(..#TYPEKEY))
    Set tGrantee = $Get(pQuery(..#GRANTEEKEY))
    If '..NamespaceDefined($Get(pQuery(..#NAMESPACEKEY))) Set tCodes = tCodes _ $ListBuild(##class(OcuPilot.Api.SqlPrivilegeError).#NAMESPACE)
    If (tGrantee = "") || ($Length(tGrantee) > ##class(OcuPilot.Api.SqlPrivilegeError).#GRANTEEMAX) || (tGrantee [ "*") || (tGrantee [ ",") Set tCodes = tCodes _ $ListBuild(##class(OcuPilot.Api.SqlPrivilegeError).#GRANTEE)
    Set tActions = ..ActionsFor(tType)
    If tActions = "" Set tCodes = tCodes _ $ListBuild(##class(OcuPilot.Api.SqlPrivilegeError).#TYPE)
    If '..ObjectValid(tType, $Get(pQuery(..#OBJECTKEY))) Set tCodes = tCodes _ $ListBuild(##class(OcuPilot.Api.SqlPrivilegeError).#OBJECT)
    If (tActions '= "") && '$ListFind(tActions, $Get(pQuery(..#ACTIONKEY))) Set tCodes = tCodes _ $ListBuild(##class(OcuPilot.Api.SqlPrivilegeError).#ACTION)
    If (tActions = "") && ($Get(pQuery(..#ACTIONKEY)) = "") Set tCodes = tCodes _ $ListBuild(##class(OcuPilot.Api.SqlPrivilegeError).#ACTION)
    If 'pRevoke && ($Data(pQuery(..#WITHGRANTKEY)) # 2) && '$ListFind($ListBuild("", "0", "1", "true", "false"), pQuery(..#WITHGRANTKEY)) Set tCodes = tCodes _ $ListBuild(##class(OcuPilot.Api.SqlPrivilegeError).#WITHGRANT)
    Quit tCodes
}

/// <p>The 422 refusal for the violation codes <var>pCodes</var>: <code>SQLPRIV.VALIDATION</code>, its
/// <code>detail.violations</code> naming each code's field with OcuPilot's sentence. Nothing is sent.</p>
ClassMethod RefuseViolations(pCodes As %List, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pHttpStatus = 422
    Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#VALIDATIONFAILED, ##class(OcuPilot.Api.SqlPrivilegeError).#VALIDATION, ##class(OcuPilot.Api.SqlPrivilegeError).#REASONVALIDATION)
    Set tViolations = []
    For tI = 1:1:$ListLength(pCodes) {
        Set tCode = $List(pCodes, tI)
        Set tRow = {}
        Do tRow.%Set("field", ##class(OcuPilot.Api.SqlPrivilegeError).FieldOf(tCode), "string")
        Do tRow.%Set("code", tCode, "string")
        Do tRow.%Set("reason", ##class(OcuPilot.Api.SqlPrivilegeError).ReasonFor(tCode), "string")
        Do tViolations.%Push(tRow)
    }
    Do pFault.%Set("detail", {"violations": (tViolations)})
    Quit $$$ERROR($$$GeneralError, ##class(OcuPilot.Api.SqlPrivilegeError).#VALIDATION)
}

/// <p>A refusal of the state the write moves out of: <var>pHttp</var> with <var>pCode</var> and its sentence,
/// under the envelope slug of that status. Unlogged: the caller may read it as a state that moved.</p>
ClassMethod Conflict(pCode As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Quit ..Refuse(409, ##class(OcuPilot.Api.Error).#CONFLICT, pCode, ##class(OcuPilot.Api.SqlPrivilegeError).ReasonFor(pCode), .pHttpStatus, .pFault)
}

/// <p>The composed read: the Rules, one list, the state it answers, and the preconditions of
/// <var>pType</var> (<parameter>GRANTSTATE</parameter> or <parameter>REVOKESTATE</parameter>).</p>
ClassMethod State(pType As %String, ByRef pQuery, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Set tSC = ..Facts(.pQuery, (pType = ..#REVOKESTATE), 1, .tFacts, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    If tFacts.%Get("SuperUser") Quit ..Conflict(##class(OcuPilot.Api.SqlPrivilegeError).#SUPERUSER, .pHttpStatus, .pFault)
    If pType = ..#GRANTSTATE {
        Set tAsked = ''tFacts.%Get("WithGrant")
        If tFacts.%Get("Held") && ('tAsked || tFacts.%Get("GrantOption")) Quit ..Conflict(##class(OcuPilot.Api.SqlPrivilegeError).#HELD, .pHttpStatus, .pFault)
    } ElseIf 'tFacts.%Get("Held") {
        Quit ..Conflict(##class(OcuPilot.Api.SqlPrivilegeError).#NOTHELD, .pHttpStatus, .pFault)
    }
    Do tFacts.%Remove("SuperUser")
    Set pResult = tFacts
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>The state of the privilege <var>pQuery</var> names, in <var>pFacts</var>: the query's own arguments
/// echoed (<code>Namespace</code>, <code>Type</code>, <code>Object</code>, <code>Action</code> and, on a
/// grant, <code>WithGrant</code> as a boolean), then <code>Held</code>, <code>GrantOption</code>,
/// <code>GrantedBy</code> and <code>Rows</code>, and <code>SuperUser</code>, which says the grantee's list is the
/// <code>%All</code> holder's. With <var>pRules</var> the Rules are asked first and refuse as 422. The list is
/// read once, in the namespace, with system objects included.</p>
ClassMethod Facts(ByRef pQuery, pRevoke As %Boolean, pRules As %Boolean, Output pFacts As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pFacts = ""
    Set pHttpStatus = 0
    Set pFault = ""
    If pRules {
        Set tCodes = ..Violations(.pQuery, pRevoke)
        If tCodes '= "" Quit ..RefuseViolations(tCodes, .pHttpStatus, .pFault)
    }
    Kill tList
    Set tList(..#NAMESPACEKEY) = pQuery(..#NAMESPACEKEY)
    Set tList(..#GRANTEEKEY) = pQuery(..#GRANTEEKEY)
    Set tList("includeSystem") = 1
    Set tList("maxRows") = ..#MAXROWS
    Set tSC = ..Call(..#ENDPOINT, ..#LISTTYPE, .tList, "", .tRows, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    If '$IsObject($Get(tRows)) || 'tRows.%IsA("%Library.DynamicArray") || (tRows.%Size() >= ..#MAXROWS) {
        Set tSC = ..Refuse(500, ##class(OcuPilot.Api.Error).#SERVERERROR, ##class(OcuPilot.Api.Error).#INTERNAL, ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON, .pHttpStatus, .pFault)
        Do ..LogFault(..#ENDPOINT _ " LIST answered something other than a complete list", $$$ERROR($$$GeneralError, "the privilege list is not an array or fills its row cap"), pFault.code)
        Quit tSC
    }
    Set tType = pQuery(..#TYPEKEY)
    Set tObject = $ZConvert(pQuery(..#OBJECTKEY), "U")
    Set tAction = $ZConvert(pQuery(..#ACTIONKEY), "U")
    Set tSchema = (tType = "SCHEMA")
    Set tViaWanted = $Select(tSchema: ..#VIASCHEMA, 1: ..#VIADIRECT)
    Set tRowCount = 0
    Set tGrantOption = 0
    Set tSuperUser = 0
    Set tGrantors = ""
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If '$IsObject(tRow) || 'tRow.%IsA("%Library.DynamicObject") Continue
        Set tVia = ..Text(tRow, ..#VIAFIELD)
        If tVia = ..#VIASUPERUSER Set tSuperUser = 1
        If tVia '= tViaWanted Continue
        If $ZConvert(..Text(tRow, "Action"), "U") '= tAction Continue
        Set tRowObject = $ZConvert(..Text(tRow, "Object"), "U")
        If tSchema {
            If $Piece(tRowObject, ".", 1) '= tObject Continue
        } Else {
            If tRowObject '= tObject Continue
            If '..TypeMatches(tType, ..Text(tRow, "Type")) Continue
        }
        Set tRowCount = tRowCount + 1
        If tRow.%Get("GrantOption") = 1 Set tGrantOption = 1
        Set tGrantor = ..Text(tRow, "GrantedBy")
        If (tGrantor '= "") && '$ListFind(tGrantors, tGrantor) Set tGrantors = tGrantors _ $ListBuild(tGrantor)
    }
    Set tFacts = {}
    Do tFacts.%Set("Namespace", pQuery(..#NAMESPACEKEY), "string")
    Do tFacts.%Set("Type", tType, "string")
    Do tFacts.%Set("Object", pQuery(..#OBJECTKEY), "string")
    Do tFacts.%Set("Action", pQuery(..#ACTIONKEY), "string")
    If 'pRevoke Do tFacts.%Set("WithGrant", ''$ListFind($ListBuild("1", "true"), $Get(pQuery(..#WITHGRANTKEY))), "boolean")
    Do tFacts.%Set("Held", ''tRowCount, "boolean")
    Do tFacts.%Set("GrantOption", ''tGrantOption, "boolean")
    Do tFacts.%Set("GrantedBy", ..Joined(tGrantors), "string")
    Do tFacts.%Set("Rows", tRowCount, "number")
    Do tFacts.%Set("SuperUser", ''tSuperUser, "boolean")
    Set pFacts = tFacts
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>Whether a listed row of type <var>pRowType</var> is the privilege of type <var>pType</var>: a table and a
/// view are alike; every other type matches itself.</p>
ClassMethod TypeMatches(pType As %String, pRowType As %String) As %Boolean
{
    If (pType = "TABLE") || (pType = "VIEW") Quit ((pRowType = "TABLE") || (pRowType = "VIEW"))
    Quit (pRowType = pType)
}

/// <p>The names in <var>pList</var>, sorted, comma-joined.</p>
ClassMethod Joined(pList As %List) As %String
{
    Kill tSorted
    For tI = 1:1:$ListLength(pList) Set tSorted($List(pList, tI)) = ""
    Set tText = ""
    Set tName = ""
    For {
        Set tName = $Order(tSorted(tName))
        If tName = "" Quit
        Set tText = tText _ $Select(tText = "": "", 1: ",") _ tName
    }
    Quit tText
}

/// <p>A grant: the state read (<parameter>GRANTSTATE</parameter>'s refusals), one vendor <code>GRANT</code>, a
/// second read. A grant that holds the grant option asked for, or raised a schema's rows, is done and answers
/// <code>{}</code>; any other state is 409 <code>SQLPRIV.NOTAPPLIED</code>.</p>
ClassMethod Grant(ByRef pQuery, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    Set tSC = ..State(..#GRANTSTATE, .pQuery, .tBefore, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Kill tSend
    Merge tSend = pQuery
    Kill tSend(..#WITHGRANTKEY)
    If tBefore.%Get("WithGrant") Set tSend(..#WITHGRANTKEY) = 1
    Set tSC = ..Call(..#ENDPOINT, ..#GRANT, .tSend, "", .pResult, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = ..Facts(.pQuery, 0, 0, .tAfter, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Set tApplied = $Select(tBefore.%Get("WithGrant"): tAfter.%Get("GrantOption"), 1: tAfter.%Get("Held"))
    If (pQuery(..#TYPEKEY) = "SCHEMA") Set tApplied = (tAfter.%Get("Rows") > tBefore.%Get("Rows")) || (tBefore.%Get("WithGrant") && tAfter.%Get("GrantOption") && 'tBefore.%Get("GrantOption"))
    If 'tApplied Quit ..Conflict(##class(OcuPilot.Api.SqlPrivilegeError).#NOTAPPLIED, .pHttpStatus, .pFault)
    Set pResult = {}
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>A revoke: the state read (<parameter>REVOKESTATE</parameter>'s refusals), one vendor <code>REVOKE</code> for
/// each grantor that read names, a second read. A revoke that lowered the rows (to none outside a schema) is done
/// and answers <code>{}</code>; any other state is 409 <code>SQLPRIV.NOTAPPLIED</code>. The first vendor refusal
/// stops the sequence and is answered.</p>
ClassMethod Revoke(ByRef pQuery, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    Set tSC = ..State(..#REVOKESTATE, .pQuery, .tBefore, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Set tGrantors = $ListFromString(tBefore.%Get("GrantedBy"), ",")
    For tI = 1:1:$ListLength(tGrantors) {
        Kill tSend
        Merge tSend = pQuery
        Kill tSend(..#WITHGRANTKEY)
        Set tSend("cascade") = 0
        Set tSend(..#ASGRANTORKEY) = $List(tGrantors, tI)
        Set tSC = ..Call(..#ENDPOINT, ..#REVOKE, .tSend, "", .pResult, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
    }
    If $$$ISERR(tSC) Quit tSC
    Set tSC = ..Facts(.pQuery, 1, 0, .tAfter, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Set tApplied = $Select(pQuery(..#TYPEKEY) = "SCHEMA": tAfter.%Get("Rows") < tBefore.%Get("Rows"), 1: 'tAfter.%Get("Rows"))
    If 'tApplied Quit ..Conflict(##class(OcuPilot.Api.SqlPrivilegeError).#NOTAPPLIED, .pHttpStatus, .pFault)
    Set pResult = {}
    Set pHttpStatus = 200
    Quit $$$OK
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
    If (pEndpoint = ..#ENDPOINT) && ((pType = ..#GRANT) || (pType = ..#REVOKE)) Quit "rest"
    Quit ##super(pEndpoint, pType)
}

/// <p><method>Invoke</method>'s branches as a script (AD-59): a grant is the one vendor call, with
/// <code>withGrant</code> only when asked; a revoke is one vendor call with <code>cascade</code> 0 and the
/// grantor as the placeholder <code>&lt;grantor&gt;</code>, followed by a <code>comment</code> step that says the
/// call is sent once for each direct grantor the instance lists. The reads, the Rules and the second read are
/// guards a script cannot carry.</p>
ClassMethod Snippet(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", pContext As %DynamicObject = "") As %DynamicArray
{
    If (pEndpoint '= ..#ENDPOINT) || ((pType '= ..#GRANT) && (pType '= ..#REVOKE)) Quit ##super(pEndpoint, pType, .pQuery, pBody, pContext)
    Kill tQuery
    Merge tQuery = pQuery
    If pType = ..#GRANT {
        If $Get(tQuery(..#WITHGRANTKEY)) '= 1 Kill tQuery(..#WITHGRANTKEY)
        Set tStep = ..RestStep(pEndpoint, pType, .tQuery, "", pContext)
        If '$IsObject(tStep) Quit []
        Quit [(tStep)]
    }
    Kill tQuery(..#WITHGRANTKEY)
    Set tQuery("cascade") = 0
    Set tQuery(..#ASGRANTORKEY) = "<grantor>"
    Set tStep = ..RestStep(pEndpoint, pType, .tQuery, "", pContext)
    If '$IsObject(tStep) Quit []
    Quit [(tStep), (..Step("comment", "Send the call once for each user that granted the privilege directly, naming that user as asGrantor."))]
}

}

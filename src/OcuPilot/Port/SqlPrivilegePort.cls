/// <p>The SQL privileges' port (AD-27, AD-52, Stories 18.9 and 18.28): <class>OcuPilot.Port.AdminPort</class> with
/// four request types composed on <code>Security.SQLPrivilege.Standard</code>, and every other call the admin
/// port's own, unchanged. It names no vendor class.</p>
/// <p><b>Three families, one set of request types.</b> A query with a <code>column</code> is the column family
/// (<code>Security.SQLPrivilege.Column</code>), and a query of type <code>ADMIN</code> is the admin family
/// (<code>Security.SQLPrivilege.Admin</code>, its privilege in <code>action</code>); every other query is the
/// standard family. Each family reads its own list, counts the grantee's <code>Direct</code> rows, sends its own
/// vendor calls and re-reads. A column query spells <code>object</code> and takes <code>type</code> from the
/// instance's own lists, because the vendor's column calls match the object's case and store a row nothing lists
/// for a view sent as a table. A grant in the column and admin families first confirms the grantee exists, because
/// the vendor stores a row for an unknown name.</p>
/// <p><b>Two composed reads.</b> <parameter>GRANTSTATE</parameter> and <parameter>REVOKESTATE</parameter> answer
/// <code>{Namespace, Type, Object, Action, Column, [WithGrant], Held, GrantOption, GrantedBy, Rows}</code> from
/// the family's lists (<parameter>MAXROWS</parameter> rows each, a full answer a fault). In the standard family,
/// outside a schema, <code>Rows</code> counts the grantee's <code>Direct</code> rows for the object and action
/// (a table and a view alike) and <code>GrantedBy</code> names their distinct grantors, sorted and comma-joined;
/// for a schema they are the <code>Schema Privilege</code> rows of the schema's objects for the action. They refuse,
/// before any vendor call and in this order: the Rules (422 <code>SQLPRIV.VALIDATION</code>, each violation
/// naming its field), a grantee holding <code>%All</code> (409 <code>SQLPRIV.SUPERUSER</code>), then a grant of
/// what is already held with the grant option asked for or more (409 <code>SQLPRIV.HELD</code>) and a revoke
/// with no direct row (409 <code>SQLPRIV.NOTHELD</code>).</p>
/// <p><b>A write is judged by a re-read.</b> The vendor answers a grant or revoke that moved nothing with 200.
/// <parameter>GRANT</parameter> reads the state, sends one vendor <code>GRANT</code> and reads again;
/// <parameter>REVOKE</parameter> sends one vendor <code>REVOKE</code> per grantor the read names, each with
/// <code>asGrantor</code> (and <code>cascade</code> 0 in the standard family), or one naming no grantor in the admin
/// family, and reads again. A state the write did not move is 409 <code>SQLPRIV.NOTAPPLIED</code>.</p>
/// <p><b>Caller contract:</b> every vendor call goes through <method>Call</method>, so a test port overrides that
/// one method. The query keys are the vendor's own: <code>grantee</code>, <code>namespace</code>,
/// <code>type</code>, <code>object</code>, <code>action</code>, <code>column</code> and, on a grant,
/// <code>withGrant</code>; the admin family sends the action as <code>privilege</code>.</p>
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

/// <p>The column and admin families' writes this port issues of its own for the four tools' action types.</p>
Parameter DELEGATEDTYPES = "Security.SQLPrivilege.Column/GRANT,Security.SQLPrivilege.Column/REVOKE,Security.SQLPrivilege.Admin/GRANT,Security.SQLPrivilege.Admin/REVOKE";

/// <p>The two other families' endpoints, and the type that selects the admin family.</p>
Parameter COLUMNENDPOINT = "Security.SQLPrivilege.Column";

Parameter ADMINENDPOINT = "Security.SQLPrivilege.Admin";

Parameter ADMINTYPE = "ADMIN";

/// <p>The query keys.</p>
Parameter GRANTEEKEY = "grantee";

Parameter NAMESPACEKEY = "namespace";

Parameter TYPEKEY = "type";

Parameter OBJECTKEY = "object";

Parameter ACTIONKEY = "action";

Parameter WITHGRANTKEY = "withGrant";

Parameter ASGRANTORKEY = "asGrantor";

Parameter COLUMNKEY = "column";

Parameter PRIVILEGEKEY = "privilege";

/// <p>The member of a listed row that says how the grantee holds the privilege, and its values.</p>
Parameter VIAFIELD = "GrantedVia";

Parameter VIADIRECT = "Direct";

Parameter VIASCHEMA = "Schema Privilege";

Parameter VIASUPERUSER = "SuperUser";

/// <p>The seven types, comma-separated, and the actions each takes (<method>ActionsFor</method>).</p>
Parameter TYPES = "TABLE,VIEW,SCHEMA,STORED PROCEDURE,ML CONFIGURATION,FOREIGN SERVER,ADMIN";

/// <p>The actions a column privilege takes, on a table or a view alike.</p>
Parameter COLUMNACTIONS = "SELECT,INSERT,UPDATE,REFERENCES";

/// <p>The admin privileges the instance takes, spelled exactly: the names the vendor's <code>GetPrivNum</code> lists
/// but <code>%DEFER</code>, which the instance's admin privilege store refuses (#514).</p>
Parameter ADMINPRIVILEGES = "%CREATE_FUNCTION,%DROP_FUNCTION,%CREATE_METHOD,%DROP_METHOD,%CREATE_PROCEDURE,%DROP_PROCEDURE,%CREATE_QUERY,%DROP_QUERY,%CREATE_TABLE,%ALTER_TABLE,%DROP_TABLE,%CREATE_VIEW,%ALTER_VIEW,%DROP_VIEW,%CREATE_TRIGGER,%DROP_TRIGGER,%NOCHECK,%NOTRIGGER,%NOINDEX,%NOLOCK,%BUILD_INDEX,%CREATE_ML_CONFIGURATION,%ALTER_ML_CONFIGURATION,%DROP_ML_CONFIGURATION,%MANAGE_MODEL,%USE_MODEL,%DROP_UNOWNED,%NOJOURN,%CANCEL_QUERY,%MANAGE_FOREIGN_SERVER,%USE_EMBEDDING";

Parameter TABLEACTIONS = "%ALTER,SELECT,INSERT,UPDATE,DELETE,REFERENCES";

Parameter VIEWACTIONS = "%ALTER,SELECT,INSERT,UPDATE,DELETE";

Parameter SCHEMAACTIONS = "%ALTER,SELECT,INSERT,UPDATE,DELETE,REFERENCES,EXECUTE";

/// <p>The action a stored procedure takes, and the one an ML configuration and a foreign server take.</p>
Parameter PROCEDUREACTIONS = "EXECUTE";

Parameter USEACTIONS = "USE";

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
    If pType = "STORED PROCEDURE" Quit $ListFromString(..#PROCEDUREACTIONS)
    If (pType = "ML CONFIGURATION") || (pType = "FOREIGN SERVER") Quit $ListFromString(..#USEACTIONS)
    If pType = ..#ADMINTYPE Quit $ListFromString(..#ADMINPRIVILEGES)
    Quit ""
}

/// <p>Whether <var>pObject</var> is a well-formed name for <var>pType</var>: one name for a schema or an ML
/// configuration, <code>schema.name</code> for every other type, each part matching
/// <parameter>NAMEPATTERN</parameter>; no object at all for <code>ADMIN</code>. A type outside
/// <parameter>TYPES</parameter> admits one name or two.</p>
ClassMethod ObjectValid(pType As %String, pObject As %String) As %Boolean
{
    If pType = ..#ADMINTYPE Quit (pObject = "")
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

/// <p>The Rules (Stories 18.9 and 18.28) over the query <var>pQuery</var>, as the violation codes that refuse it,
/// in <var>pCodes</var> as a <class>%List</class> without repeats: a namespace this instance does not define; a
/// grantee that is empty, over <parameter>OcuPilot.Api.SqlPrivilegeError.GRANTEEMAX</parameter> characters, or
/// carries <code>*</code> or a comma; a type outside <parameter>TYPES</parameter>; an object that is not a
/// well-formed name for its type (an <code>ADMIN</code> has none); an action its type does not take (an
/// <code>ADMIN</code> takes one of <parameter>ADMINPRIVILEGES</parameter>, spelled exactly); a column on any type
/// but a table or view, a column that is not one name, or a column action outside
/// <parameter>COLUMNACTIONS</parameter>; and, for a grant, a grant option that is not boolean. A revoke
/// (<var>pRevoke</var> 1) is not asked of the grant option.</p>
ClassMethod Violations(ByRef pQuery, pRevoke As %Boolean = 0) As %List
{
    Set tCodes = ""
    Set tType = $Get(pQuery(..#TYPEKEY))
    Set tGrantee = $Get(pQuery(..#GRANTEEKEY))
    Set tColumn = $Get(pQuery(..#COLUMNKEY))
    Set tAction = $Get(pQuery(..#ACTIONKEY))
    If '..NamespaceDefined($Get(pQuery(..#NAMESPACEKEY))) Set tCodes = tCodes _ $ListBuild(##class(OcuPilot.Api.SqlPrivilegeError).#NAMESPACE)
    If (tGrantee = "") || ($Length(tGrantee) > ##class(OcuPilot.Api.SqlPrivilegeError).#GRANTEEMAX) || (tGrantee [ "*") || (tGrantee [ ",") Set tCodes = tCodes _ $ListBuild(##class(OcuPilot.Api.SqlPrivilegeError).#GRANTEE)
    Set tActions = ..ActionsFor(tType)
    If tActions = "" Set tCodes = tCodes _ $ListBuild(##class(OcuPilot.Api.SqlPrivilegeError).#TYPE)
    If '..ObjectValid(tType, $Get(pQuery(..#OBJECTKEY))) Set tCodes = tCodes _ $ListBuild(##class(OcuPilot.Api.SqlPrivilegeError).#OBJECT)
    If tColumn '= "" {
        If '((tType = "TABLE") || (tType = "VIEW")) || '$Match(tColumn, ..#NAMEPATTERN) || '$ListFind($ListFromString(..#COLUMNACTIONS), tAction) Set tCodes = tCodes _ $ListBuild(##class(OcuPilot.Api.SqlPrivilegeError).#COLUMN)
    } Else {
        If (tActions '= "") && '$ListFind(tActions, tAction) Set tCodes = tCodes _ $ListBuild(##class(OcuPilot.Api.SqlPrivilegeError).#ACTION)
        If (tActions = "") && (tAction = "") Set tCodes = tCodes _ $ListBuild(##class(OcuPilot.Api.SqlPrivilegeError).#ACTION)
    }
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

/// <p>The composed read: the Rules, one family's lists, the state they answer, and the preconditions of
/// <var>pType</var> (<parameter>GRANTSTATE</parameter> or <parameter>REVOKESTATE</parameter>). A grant in the
/// column or admin family first confirms the grantee exists. <var>pSend</var> is the type and object the write
/// sends (<method>Facts</method>).</p>
ClassMethod State(pType As %String, ByRef pQuery, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, Output pSend As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Set tSC = ..Facts(.pQuery, (pType = ..#REVOKESTATE), 1, .tFacts, .pHttpStatus, .pFault, (pType = ..#GRANTSTATE), .pSend)
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
/// echoed (<code>Namespace</code>, <code>Type</code>, <code>Object</code>, <code>Action</code>,
/// <code>Column</code> and, on a grant, <code>WithGrant</code> as a boolean), then <code>Held</code>,
/// <code>GrantOption</code>, <code>GrantedBy</code> and <code>Rows</code>, and <code>SuperUser</code>, which says
/// the grantee's list is the <code>%All</code> holder's. With <var>pRules</var> the Rules are asked first and
/// refuse as 422; with <var>pCheckGrantee</var>, a column or admin query's grantee is confirmed to exist. Each
/// family's lists are read once, in the namespace, with system objects included where the list takes them.
/// <var>pSend</var> is <code>{Type, Object}</code> as the write sends them: the query's own, except in the column
/// family, where they are the instance's spelling.</p>
ClassMethod Facts(ByRef pQuery, pRevoke As %Boolean, pRules As %Boolean, Output pFacts As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, pCheckGrantee As %Boolean = 0, Output pSend As %DynamicObject) As %Status [ Private ]
{
    Set pFacts = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Set tType = $Get(pQuery(..#TYPEKEY))
    Set tColumn = $Get(pQuery(..#COLUMNKEY))
    Set pSend = {"Type": (tType), "Object": ($Get(pQuery(..#OBJECTKEY)))}
    If pRules {
        Set tCodes = ..Violations(.pQuery, pRevoke)
        If tCodes '= "" Quit ..RefuseViolations(tCodes, .pHttpStatus, .pFault)
    }
    If pCheckGrantee && ((tType = ..#ADMINTYPE) || (tColumn '= "")) {
        Set tSC = ..GranteeExists($Get(pQuery(..#GRANTEEKEY)), .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit tSC
    }
    If tType = ..#ADMINTYPE {
        Set tSC = ..AdminTally(.pQuery, .tTally, .pHttpStatus, .pFault)
    } ElseIf tColumn '= "" {
        Set tSC = ..ColumnTally(.pQuery, pRevoke, .tTally, .pSend, .pHttpStatus, .pFault)
    } Else {
        Set tSC = ..StandardTally(.pQuery, .tTally, .pHttpStatus, .pFault)
    }
    If $$$ISERR(tSC) Quit tSC
    Set tFacts = {}
    Do tFacts.%Set("Namespace", pQuery(..#NAMESPACEKEY), "string")
    Do tFacts.%Set("Type", tType, "string")
    Do tFacts.%Set("Object", $Get(pQuery(..#OBJECTKEY)), "string")
    Do tFacts.%Set("Action", pQuery(..#ACTIONKEY), "string")
    Do tFacts.%Set("Column", tColumn, "string")
    If 'pRevoke Do tFacts.%Set("WithGrant", ''$ListFind($ListBuild("1", "true"), $Get(pQuery(..#WITHGRANTKEY))), "boolean")
    Do tFacts.%Set("Held", ''tTally.%Get("Rows"), "boolean")
    Do tFacts.%Set("GrantOption", ''tTally.%Get("GrantOption"), "boolean")
    Do tFacts.%Set("GrantedBy", tTally.%Get("GrantedBy"), "string")
    Do tFacts.%Set("Rows", tTally.%Get("Rows"), "number")
    Do tFacts.%Set("SuperUser", ''tTally.%Get("SuperUser"), "boolean")
    Set pFacts = tFacts
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>One <code>LIST</code> of <var>pEndpoint</var> over <var>pList</var>, its rows in <var>pRows</var>. An answer
/// that is not an array, or that fills <parameter>MAXROWS</parameter>, is a 500 fault, because the count it would
/// feed may have been cut.</p>
ClassMethod ReadList(pEndpoint As %String, ByRef pList, Output pRows As %DynamicArray, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pRows = ""
    Set pList("maxRows") = ..#MAXROWS
    Set tSC = ..Call(pEndpoint, ..#LISTTYPE, .pList, "", .tRows, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    If '$IsObject($Get(tRows)) || 'tRows.%IsA("%Library.DynamicArray") || (tRows.%Size() >= ..#MAXROWS) {
        Set tSC = ..Refuse(500, ##class(OcuPilot.Api.Error).#SERVERERROR, ##class(OcuPilot.Api.Error).#INTERNAL, ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON, .pHttpStatus, .pFault)
        Do ..LogFault(pEndpoint _ " LIST answered something other than a complete list", $$$ERROR($$$GeneralError, "the privilege list is not an array or fills its row cap"), pFault.code)
        Quit tSC
    }
    Set pRows = tRows
    Quit $$$OK
}

/// <p>Whether <var>pName</var> is a user or a role of this instance: the vendor's <code>Security.User</code>
/// <code>GET</code>, then <code>Security.Role</code> <code>GET</code>, each of which answers an absent name 404. A
/// name neither holds is 404 <code>SQLPRIV.NOGRANTEE</code>, and nothing is sent.</p>
ClassMethod GranteeExists(pName As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    For tEndpoint = "Security.User", "Security.Role" {
        Kill tQuery
        Set tQuery("name") = pName
        Set tSC = ..Call(tEndpoint, "GET", .tQuery, "", .tResult, .pHttpStatus, .pFault)
        If $$$ISOK(tSC) Quit
        If pHttpStatus '= 404 Quit
    }
    If $$$ISOK(tSC) {
        Set pHttpStatus = 200
        Set pFault = ""
        Quit $$$OK
    }
    If pHttpStatus '= 404 Quit tSC
    Quit ..Refuse(404, ##class(OcuPilot.Api.Error).#NOTFOUND, ##class(OcuPilot.Api.SqlPrivilegeError).#NOGRANTEE, ##class(OcuPilot.Api.SqlPrivilegeError).#REASONNOGRANTEE, .pHttpStatus, .pFault)
}

/// <p>The standard family's tally of the grantee's rows for the privilege <var>pQuery</var> names, as
/// <code>{Rows, GrantOption, GrantedBy, SuperUser}</code>. Outside a schema it counts the <code>Direct</code> rows
/// for the object and action (a table and a view alike, the object compared ignoring case); for a schema, the
/// <code>Schema Privilege</code> rows of the schema's objects for the action.</p>
ClassMethod StandardTally(ByRef pQuery, Output pTally As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pTally = ""
    Kill tList
    Set tList(..#NAMESPACEKEY) = pQuery(..#NAMESPACEKEY)
    Set tList(..#GRANTEEKEY) = pQuery(..#GRANTEEKEY)
    Set tList("includeSystem") = 1
    Set tSC = ..ReadList(..#ENDPOINT, .tList, .tRows, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
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
    Set pTally = ..Tally(tRowCount, tGrantOption, tGrantors, tSuperUser)
    Quit $$$OK
}

/// <p>The column family's tally, with the object and type the write sends in <var>pSend</var>. The object is
/// spelled, and the type taken, from the <code>TABLE</code> or <code>VIEW</code> row of the grantee's standard
/// list (<code>includeSystem</code> 1) that matches ignoring case; a grant that finds none takes them from the
/// caller's own list, and when neither list has one they are the query's own. The tally counts the grantee's
/// <code>Direct</code> column rows for the column and action, compared ignoring case, from the column list of the
/// spelled object.</p>
ClassMethod ColumnTally(ByRef pQuery, pRevoke As %Boolean, Output pTally As %DynamicObject, ByRef pSend As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pTally = ""
    Kill tList
    Set tList(..#NAMESPACEKEY) = pQuery(..#NAMESPACEKEY)
    Set tList(..#GRANTEEKEY) = pQuery(..#GRANTEEKEY)
    Set tList("includeSystem") = 1
    Set tSC = ..ReadList(..#ENDPOINT, .tList, .tRows, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Set tObject = ""
    Set tType = ""
    Set tSuperUser = 0
    Do ..SpellObject(tRows, pQuery(..#OBJECTKEY), .tObject, .tType, .tSuperUser)
    If (tObject = "") && 'pRevoke {
        Kill tOwn
        Set tOwn(..#NAMESPACEKEY) = pQuery(..#NAMESPACEKEY)
        Set tOwn(..#GRANTEEKEY) = $Username
        Set tOwn("includeSystem") = 1
        Set tSC = ..ReadList(..#ENDPOINT, .tOwn, .tOwnRows, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit tSC
        Do ..SpellObject(tOwnRows, pQuery(..#OBJECTKEY), .tObject, .tType, .tIgnored)
    }
    If tObject = "" {
        Set tObject = pQuery(..#OBJECTKEY)
        Set tType = pQuery(..#TYPEKEY)
    }
    Set pSend = {"Type": (tType), "Object": (tObject)}
    Kill tColList
    Set tColList(..#NAMESPACEKEY) = pQuery(..#NAMESPACEKEY)
    Set tColList(..#GRANTEEKEY) = pQuery(..#GRANTEEKEY)
    Set tColList(..#OBJECTKEY) = tObject
    Set tColList("includeSystem") = 1
    Set tSC = ..ReadList(..#COLUMNENDPOINT, .tColList, .tColRows, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Set tColumn = $ZConvert(pQuery(..#COLUMNKEY), "U")
    Set tAction = $ZConvert(pQuery(..#ACTIONKEY), "U")
    Set tRowCount = 0
    Set tGrantOption = 0
    Set tGrantors = ""
    Set tIterator = tColRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If '$IsObject(tRow) || 'tRow.%IsA("%Library.DynamicObject") Continue
        If ..Text(tRow, ..#VIAFIELD) '= ..#VIADIRECT Continue
        If $ZConvert(..Text(tRow, "Column"), "U") '= tColumn Continue
        If $ZConvert(..Text(tRow, "Action"), "U") '= tAction Continue
        Set tRowCount = tRowCount + 1
        If tRow.%Get("GrantOption") = 1 Set tGrantOption = 1
        Set tGrantor = ..Text(tRow, "GrantedBy")
        If (tGrantor '= "") && '$ListFind(tGrantors, tGrantor) Set tGrantors = tGrantors _ $ListBuild(tGrantor)
    }
    Set pTally = ..Tally(tRowCount, tGrantOption, tGrantors, tSuperUser)
    Quit $$$OK
}

/// <p>The first <code>TABLE</code> or <code>VIEW</code> row of the standard list <var>pRows</var> whose object
/// equals <var>pObject</var> ignoring case: its spelling in <var>pObject</var> and its type in
/// <var>pType</var>, both <code>""</code> when no row matches; <var>pSuperUser</var> is 1 when any row is the
/// <code>%All</code> holder's.</p>
ClassMethod SpellObject(pRows As %DynamicArray, pGiven As %String, Output pObject As %String, Output pType As %String, Output pSuperUser As %Boolean) [ Private ]
{
    Set pObject = ""
    Set pType = ""
    Set pSuperUser = 0
    Set tUpper = $ZConvert(pGiven, "U")
    Set tIterator = pRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If '$IsObject(tRow) || 'tRow.%IsA("%Library.DynamicObject") Continue
        If ..Text(tRow, ..#VIAFIELD) = ..#VIASUPERUSER Set pSuperUser = 1
        If pObject '= "" Continue
        Set tRowType = ..Text(tRow, "Type")
        If '((tRowType = "TABLE") || (tRowType = "VIEW")) Continue
        If $ZConvert(..Text(tRow, "Object"), "U") '= tUpper Continue
        Set pObject = ..Text(tRow, "Object")
        Set pType = tRowType
    }
}

/// <p>The admin family's tally: the <code>Direct</code> rows of the grantee's admin list whose privilege is the
/// query's <code>action</code> exactly. There is no grantor to name.</p>
ClassMethod AdminTally(ByRef pQuery, Output pTally As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pTally = ""
    Kill tList
    Set tList(..#NAMESPACEKEY) = pQuery(..#NAMESPACEKEY)
    Set tList(..#GRANTEEKEY) = pQuery(..#GRANTEEKEY)
    Set tSC = ..ReadList(..#ADMINENDPOINT, .tList, .tRows, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Set tRowCount = 0
    Set tGrantOption = 0
    Set tSuperUser = 0
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If '$IsObject(tRow) || 'tRow.%IsA("%Library.DynamicObject") Continue
        Set tVia = ..Text(tRow, ..#VIAFIELD)
        If tVia = ..#VIASUPERUSER Set tSuperUser = 1
        If tVia '= ..#VIADIRECT Continue
        If ..Text(tRow, "Privilege") '= pQuery(..#ACTIONKEY) Continue
        Set tRowCount = tRowCount + 1
        If tRow.%Get("GrantOption") = 1 Set tGrantOption = 1
    }
    Set pTally = ..Tally(tRowCount, tGrantOption, "", tSuperUser)
    Quit $$$OK
}

/// <p>One family's tally as <code>{Rows, GrantOption, GrantedBy, SuperUser}</code>; <var>pGrantors</var> is a
/// <class>%List</class> or <code>""</code>, answered sorted and comma-joined.</p>
ClassMethod Tally(pRows As %Integer, pGrantOption As %Boolean, pGrantors As %List, pSuperUser As %Boolean) As %DynamicObject [ Private ]
{
    Set tTally = {}
    Do tTally.%Set("Rows", pRows, "number")
    Do tTally.%Set("GrantOption", ''pGrantOption, "boolean")
    Do tTally.%Set("GrantedBy", ..Joined(pGrantors), "string")
    Do tTally.%Set("SuperUser", ''pSuperUser, "boolean")
    Quit tTally
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

/// <p>The vendor call a write sends for the query <var>pQuery</var>: the endpoint of its family in
/// <var>pEndpoint</var> and the vendor's query in <var>pOut</var>. <var>pSend</var> is the type and object to
/// send (<method>Facts</method>); <var>pWithGrant</var> adds the grant option to a grant; <var>pGrantor</var> names
/// the grantor of a standard or column revoke.</p>
ClassMethod WriteQuery(ByRef pQuery, pSend As %DynamicObject, pRevoke As %Boolean, pWithGrant As %Boolean, pGrantor As %String, Output pEndpoint As %String, Output pOut)
{
    Kill pOut
    Set pOut(..#NAMESPACEKEY) = $Get(pQuery(..#NAMESPACEKEY))
    Set pOut(..#GRANTEEKEY) = $Get(pQuery(..#GRANTEEKEY))
    If $Get(pQuery(..#TYPEKEY)) = ..#ADMINTYPE {
        Set pEndpoint = ..#ADMINENDPOINT
        Set pOut(..#PRIVILEGEKEY) = $Get(pQuery(..#ACTIONKEY))
        If 'pRevoke && pWithGrant Set pOut(..#WITHGRANTKEY) = 1
        Quit
    }
    Set pOut(..#ACTIONKEY) = $Get(pQuery(..#ACTIONKEY))
    Set pOut(..#TYPEKEY) = pSend.%Get("Type")
    Set pOut(..#OBJECTKEY) = pSend.%Get("Object")
    Set pEndpoint = ..#ENDPOINT
    If $Get(pQuery(..#COLUMNKEY)) '= "" {
        Set pEndpoint = ..#COLUMNENDPOINT
        Set pOut(..#COLUMNKEY) = $Get(pQuery(..#COLUMNKEY))
    }
    If pRevoke {
        If pEndpoint = ..#ENDPOINT Set pOut("cascade") = 0
        Set pOut(..#ASGRANTORKEY) = pGrantor
    } ElseIf pWithGrant {
        Set pOut(..#WITHGRANTKEY) = 1
    }
}

/// <p>A grant: the state read (<parameter>GRANTSTATE</parameter>'s refusals), one vendor <code>GRANT</code> of the
/// query's family, a second read. A grant that holds the grant option asked for, or raised a schema's rows, is
/// done and answers <code>{}</code>; any other state is 409 <code>SQLPRIV.NOTAPPLIED</code>.</p>
ClassMethod Grant(ByRef pQuery, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    Set tSC = ..State(..#GRANTSTATE, .pQuery, .tBefore, .pHttpStatus, .pFault, .tSend)
    If $$$ISERR(tSC) Quit tSC
    Do ..WriteQuery(.pQuery, tSend, 0, tBefore.%Get("WithGrant"), "", .tEndpoint, .tOut)
    Set tSC = ..Call(tEndpoint, ..#GRANT, .tOut, "", .pResult, .pHttpStatus, .pFault)
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
/// each grantor that read names (one, naming none, in the admin family), a second read. A revoke that lowered the
/// rows (to none outside a schema) is done and answers <code>{}</code>; any other state is 409
/// <code>SQLPRIV.NOTAPPLIED</code>. The first vendor refusal stops the sequence and is answered.</p>
ClassMethod Revoke(ByRef pQuery, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    Set tSC = ..State(..#REVOKESTATE, .pQuery, .tBefore, .pHttpStatus, .pFault, .tSend)
    If $$$ISERR(tSC) Quit tSC
    Set tGrantors = $ListFromString(tBefore.%Get("GrantedBy"), ",")
    If pQuery(..#TYPEKEY) = ..#ADMINTYPE Set tGrantors = $ListBuild("")
    For tI = 1:1:$ListLength(tGrantors) {
        Do ..WriteQuery(.pQuery, tSend, 1, 0, $List(tGrantors, tI), .tEndpoint, .tOut)
        Set tSC = ..Call(tEndpoint, ..#REVOKE, .tOut, "", .pResult, .pHttpStatus, .pFault)
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

/// <p><method>Invoke</method>'s branches as a script (AD-59): a grant is the one vendor call of the query's
/// family, with <code>withGrant</code> only when asked; a standard or column revoke is one vendor call with the
/// grantor as the placeholder <code>&lt;grantor&gt;</code> (and <code>cascade</code> 0 in the standard family),
/// followed by a <code>comment</code> step that says the call is sent once for each direct grantor the instance
/// lists; an admin revoke is the one call, naming no grantor. The reads, the Rules, the grantee check and the second
/// read are guards a script cannot carry. A column script names the object and type as the query spells them and
/// ends with a comment saying to name them as the instance lists them, as the port's own write does.</p>
ClassMethod Snippet(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", pContext As %DynamicObject = "") As %DynamicArray
{
    If (pEndpoint '= ..#ENDPOINT) || ((pType '= ..#GRANT) && (pType '= ..#REVOKE)) Quit ##super(pEndpoint, pType, .pQuery, pBody, pContext)
    Kill tQuery
    Merge tQuery = pQuery
    Set tSend = {"Type": ($Get(tQuery(..#TYPEKEY))), "Object": ($Get(tQuery(..#OBJECTKEY)))}
    Set tRevoke = (pType = ..#REVOKE)
    Do ..WriteQuery(.tQuery, tSend, tRevoke, ($Get(tQuery(..#WITHGRANTKEY)) = 1), "<grantor>", .tEndpoint, .tOut)
    Set tStep = ..RestStep(tEndpoint, pType, .tOut, "", pContext)
    If '$IsObject(tStep) Quit []
    Set tSteps = [(tStep)]
    If tRevoke && ($Get(tQuery(..#TYPEKEY)) '= ..#ADMINTYPE) Do tSteps.%Push(..Step("comment", "Send the call once for each user that granted the privilege directly, naming that user as asGrantor."))
    If $Get(tQuery(..#COLUMNKEY)) '= "" Do tSteps.%Push(..Step("comment", "Name the object, and give its type, exactly as the instance's SQL privileges list shows them: in another letter case, or with a view's type given as TABLE, the column call changes nothing that list shows."))
    Quit tSteps
}

}

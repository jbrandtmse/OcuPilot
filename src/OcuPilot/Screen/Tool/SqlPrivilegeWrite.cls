/// <p>What the four SQL privilege tools share (AD-6, AD-51, AD-52, AD-53, Stories 18.9 and 18.28): an action-style
/// write of one privilege on a table, view, procedure, schema, ML configuration or foreign server, on one column
/// of a table or view (an optional <code>Column</code>), or an SQL admin privilege (<code>Type</code>
/// <code>ADMIN</code>, the privilege in <code>Action</code> and no object), for a user
/// (<class>OcuPilot.Screen.Descriptor.UserList</class>) or a role (<class>OcuPilot.Screen.Descriptor.RoleList</class>),
/// through <class>OcuPilot.Port.SqlPrivilegePort</class>. Two callers reach each: the editor's SQL privileges tab
/// through <class>OcuPilot.Api.ScreenAction</class>, and the agent's proposal and confirmation. None sends a body.</p>
/// <p><b>The target is the grantee.</b> The namespace, type, object and action are the write's arguments, because a
/// principal's SQL privileges are one set reached per namespace (AD-13, scope <code>instance</code>); the optional
/// grant option is a grant's. The fresh read is the port's <code>GRANTSTATE</code> or <code>REVOKESTATE</code>,
/// composed from those arguments at the mint and at a screen action (<parameter>READSVALUES</parameter>), so the
/// Rules, the grantee that holds <code>%All</code>, and a grant already held or a revoke with nothing direct to
/// remove are refused with their own <code>SQLPRIV.*</code> codes before anything is stored or sent. The confirm's
/// re-read reads the same state from the stored payload, so a state that moved closes the proposal.</p>
/// <p><b>Its fingerprint covers the arguments and the state it read</b>: the arguments travel in the stored payload
/// for <method>PortQuery</method> to send back, and <code>Held</code>, <code>GrantOption</code>,
/// <code>GrantedBy</code> and <code>Rows</code> are what the user reviewed.</p>
/// <p><b>It declares READ on the namespace's routines and globals databases</b> beyond the screen's pairs
/// (<method>ArgumentPairs</method>, AD-8), resolved at the call and refused by name before any port call, then the
/// custom resource of each <parameter>CLASSICPAGES</parameter> page (AD-44). A privilege on one of OcuPilot's own
/// schemas, and any privilege for one of OcuPilot's own roles, is refused by
/// <class>OcuPilot.Kernel.Proposal.Prohibited</class> from either caller (AD-10).</p>
Class OcuPilot.Screen.Tool.SqlPrivilegeWrite Extends OcuPilot.Screen.Tool.Write [ Abstract ]
{

/// <p>The port that reads the privilege's state, sends the grant or revokes, and judges the result (AD-52).</p>
Parameter PORTCLASS = "OcuPilot.Port.SqlPrivilegePort";

/// <p>No body: the vendor reads none for a grant or a revoke (AD-51).</p>
Parameter SENDSBODY As BOOLEAN = 0;

/// <p>The fresh read is composed from the write's own arguments (<method>PortQuery</method>), at the mint, at a
/// screen action and at the confirm.</p>
Parameter READSVALUES As BOOLEAN = 1;

/// <p>Not destructive: a revoked privilege can be granted again by the opposite proposal, which names the caller as
/// its grantor and carries the grant option only when asked.</p>
Parameter DESTRUCTIVE As BOOLEAN = 0;

/// <p>A privilege on a whole object leaves the column out, and an admin privilege leaves the object out; the Rules
/// judge what the type then lacks.</p>
Parameter SCREENOPTIONAL = "grant-sql=Object:Column,revoke-sql=Object:Column";

/// <p>The label every card row carries.</p>
Parameter STATEFIELD = "Privilege";

/// <p>A grant acts on a privilege the grantee does not hold with that grant option, and a revoke on one it
/// does.</p>
Parameter PRECONDITIONFIELD = "Held";

/// <p>What the grantee is called in the schema: <code>user</code> or <code>role</code>.</p>
Parameter GRANTEEKIND = "user or role";

/// <p>The argument names, in the order the card and the schema list them.</p>
Parameter NAMESPACEARGUMENT = "Namespace";

Parameter TYPEARGUMENT = "Type";

Parameter OBJECTARGUMENT = "Object";

Parameter ACTIONARGUMENT = "Action";

Parameter COLUMNARGUMENT = "Column";

Parameter WITHGRANTARGUMENT = "WithGrant";

ClassMethod Endpoint() As %String
{
    Quit ##class(OcuPilot.Port.SqlPrivilegePort).#ENDPOINT
}

/// <p>The vendor's query key for the grantee.</p>
ClassMethod IdParam() As %String
{
    Quit ##class(OcuPilot.Port.SqlPrivilegePort).#GRANTEEKEY
}

/// <p>Whether this tool grants (<code>1</code>) or revokes.</p>
ClassMethod Grants() As %Boolean
{
    Quit (..#WRITETYPE = ##class(OcuPilot.Port.SqlPrivilegePort).#GRANT)
}

/// <p>The arguments the write sets: the five that name the privilege, and a grant's grant option.</p>
ClassMethod SettableFields() As %List
{
    Set tNames = $ListBuild(..#NAMESPACEARGUMENT, ..#TYPEARGUMENT, ..#OBJECTARGUMENT, ..#ACTIONARGUMENT, ..#COLUMNARGUMENT)
    If ..Grants() Set tNames = tNames _ $ListBuild(..#WITHGRANTARGUMENT)
    Quit tNames
}

/// <p>The schema: the grantee, the namespace, the privilege and, on a grant, its grant option, and the agent's own
/// words. The types are closed to the seven the port takes; the object is required for every type but
/// <code>ADMIN</code>, which the Rules judge.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = {"type": "object", "properties": {}, "required": [], "additionalProperties": false}
    Set tProperties = tSchema.%Get("properties")
    Set tRequired = tSchema.%Get("required")
    Do tProperties.%Set(..IdArgument(), {"type": "string", "description": ("The " _ ..#GRANTEEKIND _ " the privilege is " _ $Select(..Grants(): "granted to", 1: "revoked from") _ ", exactly as this instance's own list reports it.")})
    Do tRequired.%Push(..IdArgument())
    Do tProperties.%Set(..#NAMESPACEARGUMENT, {"type": "string", "description": "The namespace the object is in, exactly as this instance's namespace list reports it. A namespace it does not define is refused."})
    Do tRequired.%Push(..#NAMESPACEARGUMENT)
    Set tTypes = []
    Set tTypeList = $ListFromString(##class(OcuPilot.Port.SqlPrivilegePort).#TYPES)
    For tI = 1:1:$ListLength(tTypeList) Do tTypes.%Push($List(tTypeList, tI))
    Do tProperties.%Set(..#TYPEARGUMENT, {"type": "string", "enum": (tTypes), "description": "What kind of object the privilege is on."})
    Do tRequired.%Push(..#TYPEARGUMENT)
    Do tProperties.%Set(..#OBJECTARGUMENT, {"type": "string", "description": "The object: schema.name for a table, view, stored procedure or foreign server, and one name for a schema or ML configuration; required for every type but ADMIN, which takes none. One name only; a list or a wildcard is refused."})
    Do tProperties.%Set(..#COLUMNARGUMENT, {"type": "string", "description": "One column of the table or view, to make the privilege a column privilege; omit it for a privilege on the whole object. A column takes SELECT, INSERT, UPDATE or REFERENCES. One name only."})
    Do tProperties.%Set(..#ACTIONARGUMENT, {"type": "string", "description": "One action: %ALTER, SELECT, INSERT, UPDATE, DELETE or REFERENCES on a table (a view takes no REFERENCES), those and EXECUTE on a schema, EXECUTE on a stored procedure, USE on an ML configuration or foreign server; for type ADMIN, one SQL admin privilege such as %CREATE_TABLE, spelled exactly. One action only."})
    Do tRequired.%Push(..#ACTIONARGUMENT)
    If ..Grants() Do tProperties.%Set(..#WITHGRANTARGUMENT, {"type": "boolean", "description": "Whether the grantee may grant the privilege on in turn. Omit it for false."})
    Do tProperties.%Set("rationale", {"type": "string", "description": "Why this change is being proposed, in one sentence, shown to the user above the diff."})
    Do tProperties.%Set("expectedImpact", {"type": "string", "description": "What the user should expect to happen once this is confirmed, in one sentence."})
    Do tProperties.%Set("reverse", {"type": "string", "description": "How to undo this change, in one sentence. Omit it where no reversal exists."})
    Quit tSchema
}

/// <p>The refusal of the arguments under the Rules (Story 18.9), in <var>pProblem</var>: the sentence of the first
/// violation, or <code>""</code>. The port asks the same Rules of its fresh read and refuses 422, so the mint
/// answers that first; this is the second ask, for a caller that reaches the rules without the read.</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ""
    Kill tQuery
    Set tQuery(..IdParam()) = pIdValue
    Do ..PortQuery(pArgs, .tQuery)
    Set tCodes = $ClassMethod(..#PORTCLASS, "Violations", .tQuery, '..Grants())
    If tCodes '= "" Set pProblem = ##class(OcuPilot.Api.Error).ReasonForViolation($List(tCodes, 1))
    Quit $$$OK
}

/// <p>What the caller must hold: the screen's own pairs, then the custom resource of each
/// <parameter>CLASSICPAGES</parameter> page, each pair once (AD-8, AD-44). <var>pResolved</var> is 0 when the
/// screen's pairs cannot be read.</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
    If 'pResolved Quit ""
    Quit ##class(OcuPilot.Screen.Gate).WithClassicPages(tPairs, ..#CLASSICPAGES)
}

/// <p>READ on the resources guarding the namespace <var>pArgs</var> names, its routines and globals databases,
/// resolved at the call (AD-8). A call naming no namespace, or one the instance does not define, adds none: the
/// port refuses it by its own code before any read. <var>pResolved</var> is 0 when a defined namespace's databases
/// report no resource.</p>
ClassMethod ArgumentPairs(pDescriptor As %String = "", pArgs As %DynamicObject, Output pResolved As %Boolean) As %List
{
    Set pResolved = 1
    If '$IsObject(pArgs) || (pArgs.%GetTypeOf(..#NAMESPACEARGUMENT) '= "string") Quit ""
    Set tNamespace = pArgs.%Get(..#NAMESPACEARGUMENT)
    If (tNamespace = "") || '$ClassMethod(..#PORTCLASS, "NamespaceDefined", tNamespace) Quit ""
    Do $ClassMethod(..#PORTCLASS, "NamespaceResources", tNamespace, .tResources, .tResolved)
    If 'tResolved {
        Set pResolved = 0
        Quit ""
    }
    Set tPairs = ""
    For tI = 1:1:$ListLength(tResources) Set tPairs = tPairs _ $ListBuild($ListBuild($List(tResources, tI), "READ"))
    Quit tPairs
}

/// <p>The privilege's arguments as the port's query keys, from the payload <var>pPayload</var> -- the mint's
/// arguments, a screen action's values or the stored payload -- so the read and the write name one privilege.
/// A grant option is sent as <code>1</code> or <code>0</code>.</p>
ClassMethod PortQuery(pPayload As %DynamicObject, ByRef pQuery)
{
    If '$IsObject(pPayload) Quit
    Set tKeys = $ListBuild($ListBuild(..#NAMESPACEARGUMENT, ##class(OcuPilot.Port.SqlPrivilegePort).#NAMESPACEKEY), $ListBuild(..#TYPEARGUMENT, ##class(OcuPilot.Port.SqlPrivilegePort).#TYPEKEY), $ListBuild(..#OBJECTARGUMENT, ##class(OcuPilot.Port.SqlPrivilegePort).#OBJECTKEY), $ListBuild(..#ACTIONARGUMENT, ##class(OcuPilot.Port.SqlPrivilegePort).#ACTIONKEY), $ListBuild(..#COLUMNARGUMENT, ##class(OcuPilot.Port.SqlPrivilegePort).#COLUMNKEY))
    For tI = 1:1:$ListLength(tKeys) {
        Set tPair = $List(tKeys, tI)
        If (pPayload.%GetTypeOf($List(tPair, 1)) = "string") && (pPayload.%Get($List(tPair, 1)) '= "") Set pQuery($List(tPair, 2)) = pPayload.%Get($List(tPair, 1))
    }
    If ..Grants() && (pPayload.%GetTypeOf(..#WITHGRANTARGUMENT) = "boolean") Set pQuery(##class(OcuPilot.Port.SqlPrivilegePort).#WITHGRANTKEY) = ''pPayload.%Get(..#WITHGRANTARGUMENT)
}

/// <p>The screen's declared values as this tool's arguments (AD-56 (ii)): each as sent, and the grant option from
/// <code>true</code> or <code>false</code> to a boolean; any other spelling of it is refused. The Rules are the
/// port's, asked of the fresh read.</p>
ClassMethod ScreenActionDelta(pActionId As %String, pValues As %DynamicObject, pFresh As %DynamicObject, Output pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pArgs = {}
    Set pProblem = ""
    If '$IsObject(pValues) Quit $$$OK
    For tName = ..#NAMESPACEARGUMENT, ..#TYPEARGUMENT, ..#OBJECTARGUMENT, ..#ACTIONARGUMENT, ..#COLUMNARGUMENT {
        If (pValues.%GetTypeOf(tName) = "string") && ((pValues.%Get(tName) '= "") || (tName '= ..#COLUMNARGUMENT)) && ((pValues.%Get(tName) '= "") || (tName '= ..#OBJECTARGUMENT)) Do pArgs.%Set(tName, pValues.%Get(tName), "string")
    }
    If ..Grants() && (pValues.%GetTypeOf(..#WITHGRANTARGUMENT) = "string") {
        Set tText = pValues.%Get(..#WITHGRANTARGUMENT)
        If (tText '= "true") && (tText '= "false") {
            Set pProblem = "'" _ ..#WITHGRANTARGUMENT _ "' is true or false"
            Quit $$$OK
        }
        Do pArgs.%Set(..#WITHGRANTARGUMENT, (tText = "true"), "boolean")
    }
    Quit $$$OK
}

/// <p>The privilege as the card words it: the action, the kind of object, the object (and its column) and the
/// namespace; an admin privilege is worded as one, with no object.</p>
ClassMethod Described(pFresh As %DynamicObject) As %String
{
    If pFresh.%Get(..#TYPEARGUMENT) = ##class(OcuPilot.Port.SqlPrivilegePort).#ADMINTYPE Quit pFresh.%Get(..#ACTIONARGUMENT) _ " admin privilege in " _ pFresh.%Get(..#NAMESPACEARGUMENT)
    Set tColumn = pFresh.%Get(..#COLUMNARGUMENT)
    Quit pFresh.%Get(..#ACTIONARGUMENT) _ " on " _ $Select(tColumn '= "": "column " _ tColumn _ " of ", 1: "") _ $ZConvert(pFresh.%Get(..#TYPEARGUMENT), "L") _ " " _ pFresh.%Get(..#OBJECTARGUMENT) _ " in " _ pFresh.%Get(..#NAMESPACEARGUMENT)
}

/// <p>The card's rows from the fresh read <var>pFresh</var>. A grant shows one row, the privilege moving from not
/// held (or held without the grant option) to granted, with the grant option when asked. A revoke shows one row for
/// each grantor of a direct grant, each moving to revoked. A read that answered no state is <var>pProblem</var>.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Set tSC = $$$OK
    Try {
        If '$IsObject(pFresh) || (pFresh.%GetTypeOf("Held") '= "boolean") || (pFresh.%GetTypeOf(..#OBJECTARGUMENT) '= "string") {
            Set pProblem = "this instance did not report that privilege's state"
            Quit
        }
        Set tDescribed = ..Described(pFresh)
        If ..Grants() {
            Set tBefore = $Select(pFresh.%Get("Held"): "Held without the grant option", 1: "Not held")
            Set tAfter = tDescribed _ $Select(pFresh.%Get(..#WITHGRANTARGUMENT): ", with the grant option", 1: "")
            Do pRows.%Push(..Row(tBefore, tAfter))
            Quit
        }
        Set tGrantors = $ListFromString(pFresh.%Get("GrantedBy"), ",")
        For tI = 1:1:$ListLength(tGrantors) Do pRows.%Push(..Row(tDescribed _ ", granted by " _ $List(tGrantors, tI), "Revoked"))
        If pRows.%Size() = 0 Do pRows.%Push(..Row(tDescribed, "Revoked"))
    } Catch ex {
        Set pRows = []
        Set pProblem = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>One card row.</p>
ClassMethod Row(pBefore As %String, pAfter As %String) As %DynamicObject [ Private ]
{
    Set tRow = {}
    Do tRow.%Set("field", ..#STATEFIELD, "string")
    Do tRow.%Set("before", pBefore, "string")
    Do tRow.%Set("after", pAfter, "string")
    Quit tRow
}

}

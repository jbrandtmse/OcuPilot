/// <p>The permission check (Story 16.3, FR-74, AD-8): whether a user or a role holds one resource
/// permission, and through which role. One operation, <method>Check</method>, with two callers that
/// answer the same object for the same arguments (AD-1, AD-53's shape): this class's read tool
/// <code>permissions.privileges.check</code>, and <code>GET /api/ocupilot/permissions/check</code>
/// behind the command-bar dialog on the Users and Roles lists and the user and role editors.</p>
/// <p><b>The answer is <class>OcuPilot.Kernel.Shell.Effective</class>'s one composition</b> over the
/// account's <code>Roles</code> (never its <code>EscalationRoles</code>) or over the one role being
/// checked, read as the caller behind each screen's own gate. <code>%All</code> anywhere in the
/// closure answers yes before any per-resource lookup, which is why a resource the instance does not
/// hold is refused first rather than answered.</p>
/// <p>Being a read, the tool carries no governance key (AD-22), and its result reaches the model
/// through the one sanitizer like any other (AD-60).</p>
Class OcuPilot.Kernel.Shell.PermissionCheck Extends OcuPilot.Screen.Tool.Base
{

Parameter TOOLNAME = "permissions.privileges.check";

Parameter KIND = "read";

Parameter DESCRIPTION = "Check whether a user or a role holds one resource permission (READ, WRITE or USE), composed from its roles, every role they grant and public permissions; escalation roles do not count until used. Answers held, and the role that grants it.";

/// <p>The screen this tool reads for, whose pairs are the tool's (<method>PrivilegePairs</method>).</p>
Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.UserList";

/// <p>The screen whose pairs gate a role check.</p>
Parameter ROLEDESCRIPTOR = "OcuPilot.Screen.Descriptor.RoleList";

/// <p>The two kinds of principal a check names.</p>
Parameter KINDUSER = "user";

Parameter KINDROLE = "role";

/// <p>The permissions a check names, and the letter each composes to, in the same order.</p>
Parameter PERMISSIONS = "READ,WRITE,USE";

Parameter LETTERS = "RWU";

/// <p>The longest name each kind admits: <class>%Library.Username</class>'s for a user, the
/// instance's role and resource names' for the others.</p>
Parameter USERMAXLENGTH As INTEGER = 160;

Parameter ROLEMAXLENGTH As INTEGER = 64;

Parameter RESOURCEMAXLENGTH As INTEGER = 64;

Parameter USERENDPOINT = "Security.User";

Parameter ROLEENDPOINT = "Security.Role";

Parameter RESOURCEENDPOINT = "Security.Resource";

Parameter READTYPE = "GET";

Parameter IDPARAM = "name";

/// <p>The account field a user check composes from. Its escalation roles are never read.</p>
Parameter ROLESFIELD = "Roles";

/// <p>The port every read goes through.</p>
ClassMethod PortClass() As %String
{
    Quit "OcuPilot.Port.AdminPort"
}

/// <p>The tool's input schema: all four arguments, required. The length bounds a schema cannot
/// state per kind, and blank values, are refused by <method>Check</method>.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Quit {
        "type": "object",
        "properties": {
            "kind": {"type": "string", "enum": ["user", "role"], "description": "What the name names: a user account or a role."},
            "name": {"type": "string", "maxLength": 160, "description": "The user or role name, exactly as this instance lists it (a role name is at most 64 characters)."},
            "resource": {"type": "string", "maxLength": 64, "description": "The resource name, exactly as this instance lists it, such as %DB_USER or %Admin_Secure. A resource the instance does not hold is refused."},
            "permission": {"type": "string", "enum": ["READ", "WRITE", "USE"], "description": "The permission to check on the resource."}
        },
        "required": ["kind", "name", "resource", "permission"],
        "additionalProperties": false
    }
}

/// <p>The result <method>View</method> answers: the question and its answer, nine members.</p>
ClassMethod ResultSchema(pDescriptor As %String = "") As %DynamicObject
{
    Quit {
        "type": "object",
        "properties": {
            "kind": {"type": "string", "description": "user or role, as asked."},
            "name": {"type": "string", "description": "The user or role, as asked."},
            "resource": {"type": "string", "description": "The resource, as asked."},
            "permission": {"type": "string", "description": "READ, WRITE or USE, as asked."},
            "held": {"type": "boolean", "description": "Whether the user or role holds the permission."},
            "all": {"type": "boolean", "description": "True when it holds every privilege through %All."},
            "public": {"type": "boolean", "description": "True when the permission is held only because every account holds it publicly."},
            "grantedBy": {"type": "string", "description": "The role whose own grant it is (%All for an %All holder), or empty."},
            "through": {"type": "string", "description": "For a user, the account's own role the grant is reached through when that differs from grantedBy; otherwise empty."}
        },
        "required": ["kind", "name", "resource", "permission", "held", "all", "public", "grantedBy", "through"],
        "additionalProperties": false
    }
}

/// <p>What the caller must hold: the Users list's pairs, unioned with its classic page's custom
/// resource (<method>OcuPilot.Screen.Gate.RequiredPairs</method>).</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Quit ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
}

/// <p>Declared: none (AD-3). A principal's name, a resource's name and a permission word cannot hold
/// a credential.</p>
ClassMethod SecretArguments(pDescriptor As %String = "", Output pDeclared As %Boolean) As %List
{
    Set pDeclared = 1
    Quit ""
}

/// <p>The tool's view: <var>pArgs</var> validated against <method>InputSchema</method> (400
/// <code>TOOL.ARGUMENTS</code> otherwise), then <method>Check</method>. <var>pDescriptor</var> and
/// <var>pContextCap</var> are ignored: the answer is one object, not rows.</p>
ClassMethod View(pDescriptor As %String, pArgs As %DynamicAbstractObject, pContextCap As %Integer, Output pResult As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set tSC = $$$OK
    Set pResult = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Try {
        Set tArgs = $Select($IsObject(pArgs): pArgs, pArgs = "": {}, 1: pArgs)
        Set tValidSC = ##class(OcuPilot.Screen.Tool.Registry).ValidateArguments(..InputSchema(), tArgs, .tProblem)
        If $$$ISERR(tValidSC) {
            Set tSC = ..ArgumentsRefusal(tProblem, .pHttpStatus, .pFault)
            Quit
        }
        Set tSC = ..Check(tArgs.%Get("kind"), tArgs.%Get("name"), tArgs.%Get("resource"), tArgs.%Get("permission"), .pResult, .pHttpStatus, .pFault)
    } Catch ex {
        Set pResult = ""
        Set tSC = ..InternalRefusal("the permission check tool failed: " _ ex.DisplayString(), .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>Whether <var>pName</var>, a user or a role by <var>pKind</var>, holds <var>pPermission</var>
/// (<code>READ</code>, <code>WRITE</code> or <code>USE</code>) on <var>pResource</var>, as the
/// caller may read it. <var>pAnswer</var> is
/// <code>{kind, name, resource, permission, held, all, public, grantedBy, through}</code>, filled by
/// <method>OcuPilot.Kernel.Shell.Effective.Holds</method>: <code>grantedBy</code> is the role whose
/// own grant it is (<code>%All</code> for an <code>%All</code> holder, <code>""</code> for a public
/// permission), and <code>through</code> is, for a user, the account's own role it is reached
/// through when that differs from <code>grantedBy</code>, else <code>""</code>, and always
/// <code>""</code> for a role.</p>
/// <p>Refusals, each an error status with the route's HTTP status and wire fault, in this order,
/// the dispatcher's own (a pair gate before the arguments): 403 <code>AUTH.NOPRIVILEGE</code> naming
/// the pair the Roles list's gate (for a role) or the Users list's gate lacks; 400
/// <code>TOOL.ARGUMENTS</code> naming the argument; 404 <code>USER.NAME.ABSENT</code>,
/// <code>ROLE.NAME.ABSENT</code> or <code>RESOURCE.NAME.ABSENT</code>; then the composition's own
/// gates, 403 naming the pair, or 503 <code>PERMISSION.UNCHECKED</code> when its read was cut at its
/// cap -- never an answer of no.</p>
ClassMethod Check(pKind As %String, pName As %String, pResource As %String, pPermission As %String, Output pAnswer As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set tSC = $$$OK
    Set pAnswer = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Try {
        Set tSC = ##class(OcuPilot.Kernel.Shell.Effective).Gate($Select(pKind = ..#KINDROLE: ..#ROLEDESCRIPTOR, 1: ..#DESCRIPTORCLASS), .tFailed)
        If $$$ISERR(tSC) Quit
        If tFailed '= "" {
            Set tSC = ..Denied(tFailed, .pHttpStatus, .pFault)
            Quit
        }
        Set tProblem = ..ArgumentProblem(pKind, pName, pResource, pPermission)
        If tProblem '= "" {
            Set tSC = ..ArgumentsRefusal(tProblem, .pHttpStatus, .pFault)
            Quit
        }
        Set tIsUser = (pKind = ..#KINDUSER)

        Set tSC = ..ReadOne($Select(tIsUser: ..#USERENDPOINT, 1: ..#ROLEENDPOINT), pName, .tPrincipal, .pHttpStatus, .pFault, .tAbsent)
        If $$$ISERR(tSC) Quit
        If tAbsent {
            If tIsUser {
                Set tSC = ..Refuse(404, ##class(OcuPilot.Api.Error).#NOTFOUND, ##class(OcuPilot.Api.Error).#USERNAMEABSENT, ##class(OcuPilot.Api.Error).#REASONUSERNAMEABSENT, .pHttpStatus, .pFault)
            } Else {
                Set tSC = ..Refuse(404, ##class(OcuPilot.Api.Error).#NOTFOUND, ##class(OcuPilot.Api.Error).#ROLENAMEABSENT, ##class(OcuPilot.Api.Error).#REASONROLENAMEABSENT, .pHttpStatus, .pFault)
            }
            Quit
        }
        Set tSC = ..ReadOne(..#RESOURCEENDPOINT, pResource, .tResourceRow, .pHttpStatus, .pFault, .tAbsent)
        If $$$ISERR(tSC) Quit
        If tAbsent {
            Set tSC = ..Refuse(404, ##class(OcuPilot.Api.Error).#NOTFOUND, ##class(OcuPilot.Api.Error).#RESOURCENAMEABSENT, ##class(OcuPilot.Api.Error).#REASONRESOURCENAMEABSENT, .pHttpStatus, .pFault)
            Quit
        }

        If tIsUser {
            Set tRoots = $Select(tPrincipal.%GetTypeOf(..#ROLESFIELD) = "array": tPrincipal.%Get(..#ROLESFIELD), 1: [])
        } Else {
            Set tRoots = []
            Do tRoots.%Push(pName, "string")
        }
        Set tSC = ..EffectiveRead(tRoots, .tRows, .tPublic, .tUnchecked)
        If $$$ISERR(tSC) Quit
        If tUnchecked = ##class(OcuPilot.Kernel.Shell.Effective).#TRUNCATED {
            Set tSC = ..Refuse(503, ##class(OcuPilot.Api.Error).#UNAVAILABLE, ##class(OcuPilot.Api.Error).#PERMISSIONUNCHECKED, ##class(OcuPilot.Api.Error).#REASONPERMISSIONUNCHECKED, .pHttpStatus, .pFault)
            Quit
        }
        If tUnchecked '= "" {
            Set tSC = ..Denied(tUnchecked, .pHttpStatus, .pFault)
            Quit
        }

        Set tComposed = ##class(OcuPilot.Kernel.Shell.Effective).Compose(tRoots, tRows, tPublic)
        Set tLetter = $Extract(..#LETTERS, $ListFind($ListFromString(..#PERMISSIONS), pPermission))
        Set tHolds = ##class(OcuPilot.Kernel.Shell.Effective).Holds(tComposed, pResource, tLetter)
        Set tRoot = tHolds.%Get("root")
        Set tGrantedBy = tHolds.%Get("grantedBy")
        Set tThrough = ""
        If tIsUser && (tRoot '= "") && ($ZConvert(tRoot, "U") '= $ZConvert(tGrantedBy, "U")) Set tThrough = tRoot

        Set pAnswer = {}
        Do pAnswer.%Set("kind", pKind, "string")
        Do pAnswer.%Set("name", pName, "string")
        Do pAnswer.%Set("resource", pResource, "string")
        Do pAnswer.%Set("permission", pPermission, "string")
        Do pAnswer.%Set("held", ''tHolds.%Get("held"), "boolean")
        Do pAnswer.%Set("all", ''tHolds.%Get("all"), "boolean")
        Do pAnswer.%Set("public", ''tHolds.%Get("public"), "boolean")
        Do pAnswer.%Set("grantedBy", tGrantedBy, "string")
        Do pAnswer.%Set("through", tThrough, "string")
        Set pHttpStatus = 200
        Set pFault = ""
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    If $$$ISERR(tSC) {
        Set pAnswer = ""
        If '$IsObject(pFault) Set tSC = ..InternalRefusal("the permission check failed: " _ $System.Status.GetOneErrorText(tSC), .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p><method>OcuPilot.Kernel.Shell.Effective.Read</method> for <var>pRoots</var>. A seam, so a
/// fixture can answer role rows, public permissions or a cut read.</p>
ClassMethod EffectiveRead(pRoots As %DynamicArray, Output pRoleRows As %DynamicObject, Output pPublic As %DynamicObject, Output pUnchecked As %String) As %Status
{
    Quit ##class(OcuPilot.Kernel.Shell.Effective).Read(pRoots, .pRoleRows, .pPublic, .pUnchecked)
}

/// <p>What is wrong with the four arguments, naming the argument, or <code>""</code>.</p>
ClassMethod ArgumentProblem(pKind As %String, pName As %String, pResource As %String, pPermission As %String) As %String
{
    If (pKind '= ..#KINDUSER) && (pKind '= ..#KINDROLE) Quit "'kind' is user or role"
    Set tMax = $Select(pKind = ..#KINDUSER: ..#USERMAXLENGTH, 1: ..#ROLEMAXLENGTH)
    If ($ZStrip(pName, "<>W") = "") || ($Length(pName) > tMax) Quit "'name' is required and holds at most " _ tMax _ " characters"
    If ($ZStrip(pResource, "<>W") = "") || ($Length(pResource) > ..#RESOURCEMAXLENGTH) Quit "'resource' is required and holds at most " _ ..#RESOURCEMAXLENGTH _ " characters"
    If (pPermission = "") || '$ListFind($ListFromString(..#PERMISSIONS), pPermission) Quit "'permission' is READ, WRITE or USE"
    Quit ""
}

/// <p>One object's <parameter>READTYPE</parameter> read on <var>pEndpoint</var> through
/// <method>PortClass</method>; <var>pAbsent</var> is 1 when the instance holds none by that name.
/// Any other failure is the port's own status, HTTP status and fault.</p>
ClassMethod ReadOne(pEndpoint As %String, pName As %String, Output pObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, Output pAbsent As %Boolean) As %Status [ Private ]
{
    Set pObject = ""
    Set pAbsent = 0
    Kill tQuery
    Set tQuery(..#IDPARAM) = pName
    Set tSC = $ClassMethod(..PortClass(), "Invoke", pEndpoint, ..#READTYPE, .tQuery, "", .pObject, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) {
        If +$Get(pHttpStatus) '= 404 Quit tSC
        Set pAbsent = 1
        Set pHttpStatus = 0
        Set pFault = ""
        Quit $$$OK
    }
    If '$IsObject($Get(pObject)) || 'pObject.%IsA("%Library.DynamicObject") Set pAbsent = 1
    Quit $$$OK
}

/// <p>403 <code>AUTH.NOPRIVILEGE</code> naming <var>pPair</var> (<class>OcuPilot.Kernel.Denial</class>).</p>
ClassMethod Denied(pPair As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tSC = ..Refuse(##class(OcuPilot.Kernel.Denial).#STATUS, ##class(OcuPilot.Kernel.Denial).Slug(), ##class(OcuPilot.Kernel.Denial).Code(), ##class(OcuPilot.Kernel.Denial).Reason(), .pHttpStatus, .pFault)
    Set tDetail = ##class(OcuPilot.Kernel.Denial).Detail(pPair)
    If $IsObject(tDetail) Do pFault.%Set("detail", tDetail)
    Quit tSC
}

/// <p>A refusal: <var>pStatus</var>, and the fault <code>{error, reason, code}</code>.</p>
ClassMethod Refuse(pStatus As %Integer, pSlug As %String, pCode As %String, pReason As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pHttpStatus = pStatus
    Set pFault = ##class(OcuPilot.Kernel.Fault).Build(pSlug, pCode, pReason)
    Quit $$$ERROR($$$GeneralError, pCode)
}

}

/// <p>The Roles list's change tool (AD-6, AD-10): propose a change to one role on this instance. It
/// reads the role fresh through the vendor's own <code>Security.Role</code> <code>GET</code>, merges
/// the arguments over that object, and mints a proposal the user confirms. It writes nothing.</p>
/// <p><b>It admits four fields</b>: the derived <code>Description</code> and
/// <code>EscalationOnly</code> <parameter>PERMITTEDFIELDS</parameter> names, and the authored
/// <parameter>GRANTEDROLESARGUMENT</parameter> and <parameter>RESOURCESARGUMENT</parameter>, each
/// the complete new value -- exactly the fields
/// <method>OcuPilot.Kernel.Proposal.Prohibited.PermittedChangeFields</method> has reviewed for a
/// role. A change that grants <code>%All</code> or an administrative privilege is permitted and
/// minted destructive with the privilege named (AD-10).</p>
/// <p><b>It is also the role editor's Save</b> (AD-55, <class>OcuPilot.Area.Permissions.RoleSave</class>),
/// over <code>Description</code> and <code>EscalationOnly</code> alone: grants and granted roles
/// change only by this tool's screen actions, each a delta over the fresh read (AD-56 (ii)). Both
/// callers apply the one rule set, <method>OcuPilot.Area.Permissions.RoleCreateRules.Validate</method>
/// in update mode (<method>ArgumentProblem</method>).</p>
/// <p><b>Its four screen actions</b> (AD-53, <parameter>SCREENACTIONS</parameter>) add or remove one
/// granted role, and set or remove one resource grant, each computed by
/// <method>ScreenActionDelta</method>.</p>
Class OcuPilot.Screen.Tool.RoleUpdate Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "permissions.roles.update";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.RoleList";

Parameter DESCRIPTION = "Propose a change to one role on this instance: its description, whether it is escalation-only, the roles it grants and its resource grants. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the role exactly as the roles list reports it, and send only the fields to change; a list you send replaces the role's whole list.";

Parameter READTYPE = "GET";

/// <p>The vendor's own write for an existing role: <code>Security.Role</code>'s <code>PUT</code>,
/// sent the complete property set (AD-4).</p>
Parameter WRITETYPE = "PUT";

/// <p>The derived top-level fields this tool admits, comma-separated. With
/// <parameter>GRANTEDROLESARGUMENT</parameter> and <parameter>RESOURCESARGUMENT</parameter> they are
/// <method>OcuPilot.Kernel.Proposal.Prohibited.PermittedChangeFields</method>'s role list; a test
/// asserts the two agree.</p>
Parameter PERMITTEDFIELDS = "Description,EscalationOnly";

/// <p>The authored argument holding the role's resource grants, each <code>{Name,
/// Permissions}</code>, the vendor's own shape.</p>
Parameter RESOURCESARGUMENT = "Resources";

/// <p>The authored argument holding the roles this role grants.</p>
Parameter GRANTEDROLESARGUMENT = "GrantedRoles";

/// <p>The derived argument this tool types as a boolean: the template's placeholder is a string,
/// and the instance reads and stores a boolean.</p>
Parameter ESCALATIONONLYARGUMENT = "EscalationOnly";

/// <p>The Roles list's value actions this merge write carries out (AD-53, AD-56 (ii)).</p>
Parameter SCREENACTIONS = "add-granted-role,remove-granted-role,set-resource-grant,remove-resource-grant";

/// <p>The values each action admits: a role for the two granted-role actions, a resource and its
/// letters for a grant set, and a resource for a grant removal.</p>
Parameter SCREENVALUES = "add-granted-role=Role,remove-granted-role=Role,set-resource-grant=Resource:Permissions,remove-resource-grant=Resource";

/// <p>The value names, named once.</p>
Parameter ROLEVALUE = "Role";

Parameter RESOURCEVALUE = "Resource";

Parameter PERMISSIONSVALUE = "Permissions";

/// <p>The endpoints a named role or resource is resolved against, on this tool's own port.</p>
Parameter ROLEENDPOINT = "Security.Role";

Parameter RESOURCEENDPOINT = "Security.Resource";

/// <p>The pair a change requires: <code>%Admin_Secure:USE</code>, the vendor endpoint's own
/// <code>ResourcesOR()</code> resource and one the Roles list already declares (AD-8).</p>
Parameter WRITERESOURCE = "%Admin_Secure";

Parameter WRITEPERMISSION = "USE";

ClassMethod Endpoint() As %String
{
    Quit "Security.Role"
}

/// <p>The field names the merge may set: the <code>ordinary</code> top-level fields of this tool's
/// own field-list entry that <parameter>PERMITTEDFIELDS</parameter> names (AD-3), plus the two
/// authored lists.</p>
ClassMethod SettableFields() As %List
{
    Quit ..AdmittedFields() _ $ListBuild(..#GRANTEDROLESARGUMENT, ..#RESOURCESARGUMENT)
}

/// <p><parameter>PERMITTEDFIELDS</parameter>, so a derived field the prohibited set has not
/// reviewed for a change is absent from the schema and from <method>SettableFields</method>.</p>
ClassMethod PermittedFields() As %List
{
    Quit $ListFromString(..#PERMITTEDFIELDS)
}

/// <p>The derived schema with the two authored lists added and each field described (AD-3),
/// closed with <code>additionalProperties: false</code>. A grant's own shape is
/// <method>ArgumentProblem</method>'s to refuse, because the schema subset a provider is sent
/// describes no member below a property.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) Quit tSchema
    If tSchema.%GetTypeOf("properties") '= "object" Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    Set tGrantText = "One grant, an object with exactly two members: Name, the resource as this instance's own resources list reports it, and Permissions, the letters granted from R (read), W (write) and U (use) -- a database resource (%DB_) takes R and W, and W only with R; a resource beginning with one of " _ $Replace($Parameter("OcuPilot.Area.Permissions.RoleCreateRules", "USEONLYPREFIXES"), ",", ", ") _ " takes U alone; and any other resource takes any of the three."
    Set tResources = {"type": "array", "description": "The role's complete list of resource grants after the change, one per resource. It replaces the role's current grants, so a grant left out is a grant removed. A grant of %All or of any %Admin_ resource is proposable and is confirmed as a delete is."}
    Do tResources.%Set("items", {"type": "object", "description": (tGrantText)})
    Do tProperties.%Set(..#RESOURCESARGUMENT, tResources)
    Set tGranted = {"type": "array", "description": "The complete list of roles this role grants after the change, each named exactly as this instance's own roles list reports it. It replaces the current list, so a role left out is a role removed. A role that grants %All or an administrative privilege -- by name, through another role, or as a resource it carries -- is proposable and is confirmed as a delete is."}
    Do tGranted.%Set("items", {"type": "string"})
    Do tProperties.%Set(..#GRANTEDROLESARGUMENT, tGranted)
    If tProperties.%GetTypeOf("Description") = "object" {
        Do tProperties.%Get("Description").%Set("description", "The role's description, or an empty string for none.", "string")
    }
    If tProperties.%GetTypeOf(..#ESCALATIONONLYARGUMENT) = "object" {
        Do tProperties.%Get(..#ESCALATIONONLYARGUMENT).%Set("type", "boolean", "string")
        Do tProperties.%Get(..#ESCALATIONONLYARGUMENT).%Set("description", "Whether the role is granted only by escalation, never at sign-in.", "string")
    }
    Quit tSchema
}

/// <p>The editor's own rules (<method>OcuPilot.Area.Permissions.RoleCreateRules.Validate</method>,
/// update mode) over the fields the agent's arguments change, read against this tool's own fresh
/// read of <var>pIdValue</var>, each broken rule as its field and published sentence (AD-55). A role
/// the read no longer finds has every supplied field checked; the mint has already refused one that
/// was absent when it read.</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ""
    Set tRules = "OcuPilot.Area.Permissions.RoleCreateRules"
    Kill tQuery
    Set tQuery(..IdParam()) = pIdValue
    Set tSC = $ClassMethod(..PortClass(), "Invoke", ..Endpoint(), ..ReadType(), .tQuery, "", .tFresh, .tHttp, .tFault)
    If $$$ISERR(tSC) && (+$Get(tHttp) '= 404) Quit tSC
    If '$IsObject($Get(tFresh)) || 'tFresh.%IsA("%Library.DynamicObject") Set tFresh = ""
    Set tSC = $ClassMethod(tRules, "Validate", pIdValue, $ClassMethod(tRules, "Changed", pArgs, tFresh), .tViolations, 0, 0, "update", tFresh)
    If $$$ISERR(tSC) Quit tSC
    For tI = 1:1:$Get(tViolations) {
        Set tReason = ##class(OcuPilot.Api.Error).ReasonForViolation($List(tViolations(tI), 2))
        Set pProblem = pProblem _ $Select(pProblem = "": "", 1: " ") _ "'" _ $List(tViolations(tI), 1) _ "': " _ tReason
    }
    Quit $$$OK
}

/// <p>What the caller must hold: the screen's own pairs together with
/// <parameter>WRITERESOURCE</parameter>:<parameter>WRITEPERMISSION</parameter>, each pair once.</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
    If 'pResolved Quit ""
    Set tOwn = $ListBuild(..#WRITERESOURCE, ..#WRITEPERMISSION)
    If $ListFind(tPairs, tOwn) Quit tPairs
    Quit tPairs _ $ListBuild(tOwn)
}

/// <p>The arguments a screen action sends (AD-56 (ii)), built from the fresh read <var>pFresh</var>
/// so a member another session changed after the list loaded is kept:</p>
/// <ul>
/// <li><code>add-granted-role</code> and <code>remove-granted-role</code>: the complete
/// <parameter>GRANTEDROLESARGUMENT</parameter> list plus or minus the one role
/// <var>pValues</var> names;</li>
/// <li><code>set-resource-grant</code>: the complete <parameter>RESOURCESARGUMENT</parameter> list
/// with the named resource's grant added, or its letters replaced;</li>
/// <li><code>remove-resource-grant</code>: that list without the named resource's grant.</li>
/// </ul>
/// <p>Names are matched case-insensitively, as the instance resolves them, and a held entry keeps
/// the instance's own spelling. Refused in <var>pProblem</var>: an empty value, adding what the role
/// already holds, removing what it does not, and naming a role or resource the endpoint's read,
/// through this tool's own port, answers 404 for. The grant a set names is held to
/// <method>OcuPilot.Area.Permissions.RoleCreateRules.ResourceViolation</method>, the rule the create
/// and the change apply. No problem sentence names a value.</p>
ClassMethod ScreenActionDelta(pActionId As %String, pValues As %DynamicObject, pFresh As %DynamicObject, Output pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ""
    Set tSC = $$$OK
    Try {
        If (pActionId = "add-granted-role") || (pActionId = "remove-granted-role") {
            Set tSC = ..GrantedRoleDelta(pActionId, pValues, pFresh, .pArgs, .pProblem)
            Quit
        }
        If (pActionId = "set-resource-grant") || (pActionId = "remove-resource-grant") {
            Set tSC = ..GrantDelta(pActionId, pValues, pFresh, .pArgs, .pProblem)
            Quit
        }
        Set tSC = ##super(pActionId, pValues, pFresh, .pArgs, .pProblem)
    } Catch ex {
        Set pArgs = {}
        Set pProblem = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The granted-role half of <method>ScreenActionDelta</method>.</p>
ClassMethod GrantedRoleDelta(pActionId As %String, pValues As %DynamicObject, pFresh As %DynamicObject, Output pArgs As %DynamicObject, Output pProblem As %String) As %Status [ Private ]
{
    Set pArgs = {}
    Set pProblem = ""
    Set tRole = ""
    If $IsObject(pValues) Set tRole = $ZStrip(pValues.%Get(..#ROLEVALUE), "<>W")
    If tRole = "" {
        Set pProblem = "'" _ ..#ROLEVALUE _ "' names the role and cannot be empty"
        Quit $$$OK
    }
    Set tWanted = $ZConvert(tRole, "U")
    Set tRoles = []
    Set tHeld = 0
    If $IsObject(pFresh) && (pFresh.%GetTypeOf(..#GRANTEDROLESARGUMENT) = "array") {
        Set tIterator = pFresh.%Get(..#GRANTEDROLESARGUMENT).%GetIterator()
        While tIterator.%GetNext(.tIndex, .tOne) {
            If $IsObject(tOne) || (tOne = "") Continue
            If $ZConvert(tOne, "U") = tWanted {
                Set tHeld = 1
                If pActionId = "remove-granted-role" Continue
            }
            Do tRoles.%Push(tOne)
        }
    }
    If pActionId = "remove-granted-role" {
        If 'tHeld {
            Set pProblem = "the role does not grant that role"
            Quit $$$OK
        }
    } Else {
        If tHeld {
            Set pProblem = "the role already grants that role"
            Quit $$$OK
        }
        Set tSC = ..Exists(..#ROLEENDPOINT, tRole, .tExists)
        If $$$ISERR(tSC) Quit tSC
        If 'tExists {
            Set pProblem = "this instance holds no role by that name"
            Quit $$$OK
        }
        Do tRoles.%Push(tRole)
    }
    Do pArgs.%Set(..#GRANTEDROLESARGUMENT, tRoles)
    Quit $$$OK
}

/// <p>The resource-grant half of <method>ScreenActionDelta</method>.</p>
ClassMethod GrantDelta(pActionId As %String, pValues As %DynamicObject, pFresh As %DynamicObject, Output pArgs As %DynamicObject, Output pProblem As %String) As %Status [ Private ]
{
    Set pArgs = {}
    Set pProblem = ""
    Set tSetting = (pActionId = "set-resource-grant")
    Set tResource = ""
    Set tLetters = ""
    If $IsObject(pValues) {
        Set tResource = $ZStrip(pValues.%Get(..#RESOURCEVALUE), "<>W")
        If tSetting Set tLetters = $ZConvert($ZStrip(pValues.%Get(..#PERMISSIONSVALUE), "<>W"), "U")
    }
    If tResource = "" {
        Set pProblem = "'" _ ..#RESOURCEVALUE _ "' names the resource and cannot be empty"
        Quit $$$OK
    }
    If tSetting && (tLetters = "") {
        Set pProblem = "'" _ ..#PERMISSIONSVALUE _ "' names the letters granted and cannot be empty"
        Quit $$$OK
    }
    Set tLetters = ..Canonical(tLetters)
    Set tWanted = $ZConvert(tResource, "U")
    Set tGrants = []
    Set tHeld = 0
    Set tSame = 0
    If $IsObject(pFresh) && (pFresh.%GetTypeOf(..#RESOURCESARGUMENT) = "array") {
        Set tIterator = pFresh.%Get(..#RESOURCESARGUMENT).%GetIterator()
        While tIterator.%GetNext(.tIndex, .tGrant) {
            If '$IsObject(tGrant) || 'tGrant.%IsA("%Library.DynamicObject") Continue
            Set tName = tGrant.%Get("Name")
            If tName = "" Continue
            Set tOne = {}
            Do tOne.%Set("Name", tName, "string")
            Do tOne.%Set("Permissions", tGrant.%Get("Permissions"), "string")
            If $ZConvert(tName, "U") = tWanted {
                Set tHeld = 1
                If 'tSetting Continue
                Set tSame = (..Canonical(tGrant.%Get("Permissions")) = tLetters)
                Do tOne.%Set("Permissions", tLetters, "string")
            }
            Do tGrants.%Push(tOne)
        }
    }
    If 'tSetting {
        If 'tHeld Set pProblem = "the role does not grant that resource"
        If pProblem = "" Do pArgs.%Set(..#RESOURCESARGUMENT, tGrants)
        Quit $$$OK
    }
    If tSame {
        Set pProblem = "the role already grants that resource with those permissions"
        Quit $$$OK
    }
    Set tSC = ..Exists(..#RESOURCEENDPOINT, tResource, .tExists)
    If $$$ISERR(tSC) Quit tSC
    If 'tExists {
        Set pProblem = "this instance holds no resource by that name"
        Quit $$$OK
    }
    If 'tHeld Do tGrants.%Push({"Name": (tResource), "Permissions": (tLetters)})
    ; The one grant this action sets is what the rule is asked about; a grant the role already
    ; carries is the instance's, and this action does not change it.
    Set tCandidate = {}
    Do tCandidate.%Set(..#RESOURCESARGUMENT, [{"Name": (tResource), "Permissions": (tLetters)}])
    Kill tViolations
    Set tViolations = 0
    Set tSC = ##class(OcuPilot.Area.Permissions.RoleCreateRules).ResourceViolation(tCandidate, .tViolations)
    If $$$ISERR(tSC) Quit tSC
    For tI = 1:1:tViolations {
        Set tReason = ##class(OcuPilot.Api.Error).ReasonForViolation($List(tViolations(tI), 2))
        Set pProblem = pProblem _ $Select(pProblem = "": "", 1: " ") _ "'" _ $List(tViolations(tI), 1) _ "': " _ tReason
    }
    If pProblem '= "" Quit $$$OK
    Do pArgs.%Set(..#RESOURCESARGUMENT, tGrants)
    Quit $$$OK
}

/// <p>Whether <var>pEndpoint</var>'s single-object read, through this tool's own port, finds
/// <var>pName</var>, in <var>pExists</var>. Only a 404 is "absent"; any other refusal is an error
/// status.</p>
ClassMethod Exists(pEndpoint As %String, pName As %String, Output pExists As %Boolean) As %Status [ Private ]
{
    Set pExists = 0
    Kill tQuery
    Set tQuery("name") = pName
    Set tSC = $ClassMethod(..PortClass(), "Invoke", pEndpoint, "GET", .tQuery, "", .tObject, .tHttp, .tFault)
    If $$$ISERR(tSC) {
        If +$Get(tHttp) = 404 Quit $$$OK
        Quit tSC
    }
    Set pExists = 1
    Quit $$$OK
}

/// <p><var>pLetters</var> as the distinct permission letters it carries, upper-cased, in the order
/// the vendor writes them; a letter outside that set is kept at the end so the grant rule refuses
/// it rather than this method dropping it.</p>
ClassMethod Canonical(pLetters As %String) As %String [ Private ]
{
    Set tUpper = $ZConvert(pLetters, "U")
    Set tOrder = $Parameter("OcuPilot.Area.Permissions.RoleCreateRules", "LETTERS")
    Set tOut = ""
    For tI = 1:1:$Length(tOrder) {
        If tUpper [ $Extract(tOrder, tI) Set tOut = tOut _ $Extract(tOrder, tI)
    }
    For tI = 1:1:$Length(tUpper) {
        Set tLetter = $Extract(tUpper, tI)
        If '(tOrder [ tLetter) Set tOut = tOut _ tLetter
    }
    Quit tOut
}

}

/// <p>The Role form's rules (AD-39, AD-55): the one rule set both callers of
/// <class>OcuPilot.Screen.Tool.RoleCreate</class> apply (<method>Validate</method>), the resource
/// grant's admissible permissions (<method>AdmissiblePermissions</method>), the form's bootstrap
/// read (<method>HandleForm</method>), and the name look-up (<method>HandleName</method>,
/// <method>Taken</method>).</p>
/// <p><b>Every sentence is <method>OcuPilot.Api.Error.ReasonForViolation</method>'s</b>, and the
/// bootstrap read serves the same sentences, so an inline blur refusal and a failed Save are one
/// wording. Which choices grant privilege is the prohibited set's one classifier
/// (<method>OcuPilot.Kernel.Proposal.Prohibited.GrantsPrivilegeByEffect</method>'s per-choice
/// halves), never decided here.</p>
/// <p>Role and resource names are looked up in <code>%SYS</code> by AD-16's explicit save and
/// restore; both compare without regard to case, as <class>Security.Roles</class> and
/// <class>Security.Resources</class> do.</p>
Class OcuPilot.Area.Permissions.RoleCreateRules Extends %RegisteredObject
{

/// <p>The tool both callers resolve the write through (AD-55).</p>
Parameter TOOLCLASS = "OcuPilot.Screen.Tool.RoleCreate";

/// <p>The form screen whose declared pairs gate these routes (AD-8).</p>
Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.RoleForm";

/// <p>The fields a create must carry, comma-separated.</p>
Parameter REQUIREDFIELDS = "Name";

/// <p>The longest role name and description <class>Security.Roles</class> stores: the
/// <code>MAXLEN</code> of its <code>Name</code> and <code>Description</code> properties on this
/// build.</p>
Parameter NAMEMAXLENGTH As INTEGER = 64;

Parameter DESCRIPTIONMAXLENGTH As INTEGER = 256;

/// <p>The characters a role name may not carry beyond the control characters: the separators
/// <class>Security.Roles</class> keeps role and resource lists in.</p>
Parameter NAMEFORBIDDEN = ",:";

/// <p>The prefix only the instance's own predefined roles carry.</p>
Parameter SYSTEMPREFIX = "%";

/// <p>The endpoint and request type the resource picker lists through, on the tool's own port.</p>
Parameter RESOURCEENDPOINT = "Security.Resource";

Parameter RESOURCELISTTYPE = "LIST";

/// <p>The resource-name prefixes whose grant the classic grant dialog offers <b>Use</b> alone for,
/// comma-separated, ported from <code>%CSP.UI.Portal.Dialog.RoleResourceEdit.DrawPermissions</code>
/// (its <code>ShowRW = 0</code> branch, the <code>%sySecurity.inc</code> prefixes on this build).</p>
Parameter USEONLYPREFIXES = "%Service_,%DeepSee_,%Admin_,%Development,%Application_,%System_,%DocDB_,%Gateway_,%IAM,%Native_,%SQL,%Secure_";

/// <p>The prefix whose grant that dialog offers <b>Read</b> and <b>Write</b> alone for, a
/// database's resource (its <code>ShowUse = 0</code> branch).</p>
Parameter DATABASEPREFIX = "%DB_";

/// <p>The permission letters a grant is written in, in the order the vendor writes them.</p>
Parameter LETTERS = "RWU";

/// <p>The body fields the rules read, named once.</p>
Parameter FIELDNAME = "Name";

Parameter FIELDDESCRIPTION = "Description";

Parameter FIELDRESOURCES = "Resources";

Parameter FIELDGRANTEDROLES = "GrantedRoles";

/// <p>Every rule a create applies, in <var>pViolations</var> as
/// <code>pViolations(n) = $ListBuild(field, code)</code> with the count in
/// <code>pViolations</code>.</p>
/// <p><var>pCheckName</var> 0 skips the name's own rules, for a caller that has already applied
/// them; <var>pCheckTaken</var> 0 skips the name look-up, for the agent's mint, which has read the
/// target's absence (<method>OcuPilot.Screen.Tool.RoleCreate.ArgumentProblem</method>).</p>
ClassMethod Validate(pName As %String, pArgs As %DynamicObject, Output pViolations, pCheckName As %Boolean = 1, pCheckTaken As %Boolean = 1) As %Status
{
    Kill pViolations
    Set pViolations = 0
    Set tSC = $$$OK
    Try {
        If pCheckName Do ..NameViolation(pName, .pViolations)
        If (pViolations = 0) && pCheckTaken {
            Set tTakenSC = ..Taken(pName, .tTaken)
            If $$$ISERR(tTakenSC) {
                Set tSC = tTakenSC
                Quit
            }
            If tTaken Do ..Add(.pViolations, ..#FIELDNAME, ##class(OcuPilot.Api.Error).#ROLENAMETAKEN)
        }

        If $IsObject(pArgs) {
            Set tType = pArgs.%GetTypeOf(..#FIELDDESCRIPTION)
            If (tType = "object") || (tType = "array") {
                Do ..Add(.pViolations, ..#FIELDDESCRIPTION, ##class(OcuPilot.Api.Error).#PORTFIELDSHAPE)
            } ElseIf (tType '= "unassigned") && (tType '= "null") && ($Length(pArgs.%Get(..#FIELDDESCRIPTION)) > ..#DESCRIPTIONMAXLENGTH) {
                Do ..Add(.pViolations, ..#FIELDDESCRIPTION, ##class(OcuPilot.Api.Error).#ROLEDESCRIPTIONLENGTH)
            }
        }

        Set tSC = ..ResourceViolation(pArgs, .pViolations)
        If $$$ISERR(tSC) Quit
        Set tSC = ..GrantedRoleViolation(pArgs, .pViolations)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Add the name's own violation to <var>pViolations</var>, or none: an absent name, one longer
/// than <parameter>NAMEMAXLENGTH</parameter>, one carrying a control character or a character of
/// <parameter>NAMEFORBIDDEN</parameter>, and one beginning <parameter>SYSTEMPREFIX</parameter>.</p>
ClassMethod NameViolation(pName As %String, Output pViolations)
{
    If pName = "" {
        Do ..Add(.pViolations, ..#FIELDNAME, ##class(OcuPilot.Api.Error).#ROLENAMEREQUIRED)
        Quit
    }
    If $Length(pName) > ..#NAMEMAXLENGTH {
        Do ..Add(.pViolations, ..#FIELDNAME, ##class(OcuPilot.Api.Error).#ROLENAMELENGTH)
        Quit
    }
    Set tUsable = 1
    For tI = 1:1:$Length(..#NAMEFORBIDDEN) {
        If pName [ $Extract(..#NAMEFORBIDDEN, tI) Set tUsable = 0 Quit
    }
    For tI = 1:1:$Length(pName) {
        Set tCode = $Ascii(pName, tI)
        If (tCode < 32) || (tCode = 127) Set tUsable = 0 Quit
    }
    If 'tUsable {
        Do ..Add(.pViolations, ..#FIELDNAME, ##class(OcuPilot.Api.Error).#ROLENAMESHAPE)
        Quit
    }
    If $Extract(pName, 1) = ..#SYSTEMPREFIX Do ..Add(.pViolations, ..#FIELDNAME, ##class(OcuPilot.Api.Error).#ROLENAMESYSTEM)
}

/// <p>The permission letters the classic grant dialog offers for resource <var>pResource</var>, in
/// <parameter>LETTERS</parameter> order: <code>RW</code> for a database's resource
/// (<parameter>DATABASEPREFIX</parameter>), <code>U</code> for one
/// <parameter>USEONLYPREFIXES</parameter> names, and <code>RWU</code> for any other. The prefixes
/// compare without regard to case, because the instance resolves a resource name that way and an
/// agent may send another spelling.</p>
ClassMethod AdmissiblePermissions(pResource As %String) As %String
{
    Set tName = $ZConvert(pResource, "U")
    If ..IsDatabaseResource(pResource) Quit "RW"
    Set tUseOnly = 0
    For tI = 1:1:$Length(..#USEONLYPREFIXES, ",") {
        Set tPrefix = $ZConvert($Piece(..#USEONLYPREFIXES, ",", tI), "U")
        If (tPrefix '= "") && ($Extract(tName, 1, $Length(tPrefix)) = tPrefix) Set tUseOnly = 1
    }
    If tUseOnly Quit "U"
    Quit ..#LETTERS
}

/// <p>Whether <var>pResource</var> is a database's resource (<parameter>DATABASEPREFIX</parameter>),
/// compared without regard to case.</p>
ClassMethod IsDatabaseResource(pResource As %String) As %Boolean
{
    Quit $Extract($ZConvert(pResource, "U"), 1, $Length(..#DATABASEPREFIX)) = $ZConvert(..#DATABASEPREFIX, "U")
}

/// <p>Whether <var>pPermissions</var> is a grant resource <var>pResource</var> admits: at least one
/// letter, every letter one <method>AdmissiblePermissions</method> answers, and none twice. Case is
/// not significant.</p>
ClassMethod PermissionsAdmitted(pResource As %String, pPermissions As %String) As %Boolean
{
    Set tLetters = $ZConvert(pPermissions, "U")
    If tLetters = "" Quit 0
    Set tAdmitted = ..AdmissiblePermissions(pResource)
    Set tOk = 1
    For tI = 1:1:$Length(tLetters) {
        Set tLetter = $Extract(tLetters, tI)
        If '(tAdmitted [ tLetter) Set tOk = 0 Quit
        If $Length(tLetters, tLetter) > 2 Set tOk = 0 Quit
    }
    Quit tOk
}

/// <p>Add the resource grants' violations to <var>pViolations</var>, each code at most once: a
/// member that is not a list of <code>{Name, Permissions}</code> objects naming a resource
/// (<code>SHAPE</code>, which stops the other checks); a resource this instance does not hold
/// (<code>UNKNOWN</code>); a resource granted twice (<code>DUPLICATE</code>); a grant whose
/// letters its resource does not admit (<code>PERMISSIONS</code>); and a database's resource
/// granted Write without Read (<code>WRITEONLY</code>, the classic dialog's
/// <code>writeChanged</code>). An absent member grants nothing.</p>
ClassMethod ResourceViolation(pArgs As %DynamicObject, Output pViolations) As %Status
{
    Set tSC = $$$OK
    If '$IsObject(pArgs) Quit tSC
    Set tType = pArgs.%GetTypeOf(..#FIELDRESOURCES)
    If tType = "unassigned" Quit tSC
    If tType '= "array" {
        Do ..Add(.pViolations, ..#FIELDRESOURCES, ##class(OcuPilot.Api.Error).#ROLERESOURCESSHAPE)
        Quit tSC
    }
    Set tGrants = ""
    Set tShape = 0
    Set tIterator = pArgs.%Get(..#FIELDRESOURCES).%GetIterator()
    While tIterator.%GetNext(.tIndex, .tGrant) {
        If '$IsObject(tGrant) || 'tGrant.%IsA("%Library.DynamicObject") Set tShape = 1 Quit
        If (tGrant.%GetTypeOf("Name") '= "string") || (tGrant.%Get("Name") = "") Set tShape = 1 Quit
        If tGrant.%GetTypeOf("Permissions") '= "string" Set tShape = 1 Quit
        Set tKeyIterator = tGrant.%GetIterator()
        While tKeyIterator.%GetNext(.tKey, .tIgnored) {
            If (tKey '= "Name") && (tKey '= "Permissions") Set tShape = 1
        }
        If tShape Quit
        Set tGrants = tGrants _ $ListBuild($ListBuild(tGrant.%Get("Name"), tGrant.%Get("Permissions")))
    }
    If tShape {
        Do ..Add(.pViolations, ..#FIELDRESOURCES, ##class(OcuPilot.Api.Error).#ROLERESOURCESSHAPE)
        Quit tSC
    }
    If tGrants = "" Quit tSC
    Set tOrigNS = $NAMESPACE
    Try {
        Set tUnknown = 0
        Set $NAMESPACE = "%SYS"
        For tI = 1:1:$ListLength(tGrants) {
            If '##class(Security.Resources).Exists($List($List(tGrants, tI), 1)) Set tUnknown = 1 Quit
        }
        Set $NAMESPACE = tOrigNS
        If tUnknown Do ..Add(.pViolations, ..#FIELDRESOURCES, ##class(OcuPilot.Api.Error).#ROLERESOURCESUNKNOWN)
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    If $$$ISERR(tSC) Quit tSC
    Kill tSeen
    Set tDuplicate = 0
    Set tLetters = 0
    Set tWriteOnly = 0
    For tI = 1:1:$ListLength(tGrants) {
        Set tName = $List($List(tGrants, tI), 1)
        Set tPermissions = $ZConvert($List($List(tGrants, tI), 2), "U")
        Set tKey = $ZConvert(tName, "U")
        If $Data(tSeen(tKey)) Set tDuplicate = 1
        Set tSeen(tKey) = ""
        If '..PermissionsAdmitted(tName, tPermissions) Set tLetters = 1
        If ..IsDatabaseResource(tName) && (tPermissions [ "W") && '(tPermissions [ "R") Set tWriteOnly = 1
    }
    If tDuplicate Do ..Add(.pViolations, ..#FIELDRESOURCES, ##class(OcuPilot.Api.Error).#ROLERESOURCESDUPLICATE)
    If tLetters Do ..Add(.pViolations, ..#FIELDRESOURCES, ##class(OcuPilot.Api.Error).#ROLERESOURCESPERMISSIONS)
    If tWriteOnly Do ..Add(.pViolations, ..#FIELDRESOURCES, ##class(OcuPilot.Api.Error).#ROLERESOURCESWRITEONLY)
    Quit tSC
}

/// <p>Add the granted roles' violation to <var>pViolations</var>, or none: a member that is not a
/// list of role names, or one naming a role the instance does not hold. An absent member grants no
/// role.</p>
ClassMethod GrantedRoleViolation(pArgs As %DynamicObject, Output pViolations) As %Status
{
    Set tSC = $$$OK
    If '$IsObject(pArgs) Quit tSC
    Set tType = pArgs.%GetTypeOf(..#FIELDGRANTEDROLES)
    If tType = "unassigned" Quit tSC
    If tType '= "array" {
        Do ..Add(.pViolations, ..#FIELDGRANTEDROLES, ##class(OcuPilot.Api.Error).#ROLEGRANTEDROLESSHAPE)
        Quit tSC
    }
    Set tNames = ""
    Set tIterator = pArgs.%Get(..#FIELDGRANTEDROLES).%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRole, .tRoleType) {
        If (tRoleType '= "string") || (tRole = "") {
            Set tNames = ""
            Do ..Add(.pViolations, ..#FIELDGRANTEDROLES, ##class(OcuPilot.Api.Error).#ROLEGRANTEDROLESSHAPE)
            Quit
        }
        Set tNames = tNames _ $ListBuild(tRole)
    }
    If tNames = "" Quit tSC
    Set tOrigNS = $NAMESPACE
    Try {
        Set tUnknown = 0
        Set $NAMESPACE = "%SYS"
        For tI = 1:1:$ListLength(tNames) {
            If '##class(Security.Roles).Exists($List(tNames, tI)) Set tUnknown = 1 Quit
        }
        Set $NAMESPACE = tOrigNS
        If tUnknown Do ..Add(.pViolations, ..#FIELDGRANTEDROLES, ##class(OcuPilot.Api.Error).#ROLEGRANTEDROLESUNKNOWN)
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Answer <code>GET /roles/form</code>: everything the create form needs before it can draw a
/// field (AD-39): <code>{requiredFields, maxLengths, rules, roles, resources}</code>.</p>
/// <p><code>roles</code> is <method>OcuPilot.Area.Permissions.UserCreateRules.Roles</method>'s
/// <code>[{name, privileged}]</code>. <code>resources</code> is
/// <code>[{name, permissions, privileged}]</code>, listed through the tool's own port:
/// <code>permissions</code> the letters the resource admits (<method>AdmissiblePermissions</method>)
/// and <code>privileged</code> whether a grant of it grants <code>%All</code> or an administrative
/// privilege, asked of the prohibited set's classifier. The form states the grant's consequence
/// while a privileged choice is selected; it refuses nothing.</p>
ClassMethod HandleForm() As %Status
{
    Set tSC = $$$OK
    Try {
        Set tGateSC = ..Gate(.tRefused)
        If tRefused || $$$ISERR(tGateSC) {
            Set tSC = tGateSC
            Quit
        }
        Set tRolesSC = ##class(OcuPilot.Area.Permissions.UserCreateRules).Roles(.tRoles)
        If $$$ISOK(tRolesSC) Set tRolesSC = ..Resources(.tResources)
        If $$$ISERR(tRolesSC) {
            Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tRolesSC))
            Quit
        }
        Set tBody = {}
        Do tBody.%Set("requiredFields", ..Names(..#REQUIREDFIELDS))
        Set tLengths = {}
        Do tLengths.%Set(..#FIELDNAME, ..#NAMEMAXLENGTH, "number")
        Do tLengths.%Set(..#FIELDDESCRIPTION, ..#DESCRIPTIONMAXLENGTH, "number")
        Do tBody.%Set("maxLengths", tLengths)
        Do tBody.%Set("rules", ..Rules())
        Do tBody.%Set("roles", tRoles)
        Do tBody.%Set("resources", tResources)
        Set tSC = ##class(OcuPilot.Api.Response).JSON(tBody)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>Answer <code>GET /roles/name?name=&lt;n&gt;</code>: whether that name is free, in
/// <code>{name, available, reason}</code>. A look-up that cannot be made is a refusal envelope,
/// never an assertion that the name is free.</p>
ClassMethod HandleName() As %Status
{
    Set tSC = $$$OK
    Try {
        Set tGateSC = ..Gate(.tRefused)
        If tRefused || $$$ISERR(tGateSC) {
            Set tSC = tGateSC
            Quit
        }
        Set tName = $Get(%request.Data("name", 1))
        If tName = "" {
            Set tSC = ##class(OcuPilot.Area.Permissions.RoleCreate).RenderOne(..#FIELDNAME, ##class(OcuPilot.Api.Error).#ROLENAMEREQUIRED)
            Quit
        }
        Set tTakenSC = ..Taken(tName, .tTaken)
        If $$$ISERR(tTakenSC) {
            Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tTakenSC))
            Quit
        }
        Set tBody = {}
        Do tBody.%Set("name", tName, "string")
        Do tBody.%Set("available", 'tTaken, "boolean")
        Do tBody.%Set("reason", $Select(tTaken: ##class(OcuPilot.Api.Error).ReasonForViolation(##class(OcuPilot.Api.Error).#ROLENAMETAKEN), 1: ""), "string")
        Set tSC = ##class(OcuPilot.Api.Response).JSON(tBody)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>Whether a role already carries <var>pName</var>, in <var>pTaken</var>, read through the
/// create tool's own port, endpoint and read type (AD-52). A role name is compared without regard
/// to case, so the read answers for a name in any case.</p>
/// <p><b>Caller contract:</b> an error status means the question was not answered; only a 404 is
/// "free".</p>
ClassMethod Taken(pName As %String, Output pTaken As %Boolean) As %Status
{
    Set pTaken = 0
    Set tSC = $$$OK
    Try {
        Set tClass = ..#TOOLCLASS
        Kill tQuery
        Set tQuery($ClassMethod(tClass, "IdParam")) = pName
        Set tReadSC = $ClassMethod($ClassMethod(tClass, "PortClass"), "Invoke", $ClassMethod(tClass, "Endpoint"), $ClassMethod(tClass, "ReadType"), .tQuery, "", .tFresh, .tHttp, .tFault)
        If $$$ISERR(tReadSC) {
            If +$Get(tHttp) = 404 Quit
            Set tSC = tReadSC
            Quit
        }
        Set pTaken = ($IsObject(tFresh) && tFresh.%IsA("%Library.DynamicObject"))
    } Catch ex {
        Set pTaken = 0
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The resources this instance holds, as <code>[{name, permissions, privileged}]</code> in the
/// order the vendor lists them, read through the create tool's own port (AD-52).</p>
ClassMethod Resources(Output pResources As %DynamicArray) As %Status
{
    Set pResources = []
    Set tSC = $$$OK
    Try {
        Set tClass = ..#TOOLCLASS
        Kill tQuery
        Set tSC = $ClassMethod($ClassMethod(tClass, "PortClass"), "Invoke", ..#RESOURCEENDPOINT, ..#RESOURCELISTTYPE, .tQuery, "", .tList, .tHttp, .tFault)
        If $$$ISERR(tSC) Quit
        If '$IsObject(tList) || 'tList.%IsA("%Library.DynamicArray") Quit
        Set tIterator = tList.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tRow) {
            If '$IsObject(tRow) Continue
            Set tName = tRow.%Get("Name")
            If tName = "" Continue
            Set tEntry = {}
            Do tEntry.%Set("name", tName, "string")
            Do tEntry.%Set("permissions", ..AdmissiblePermissions(tName), "string")
            Do tEntry.%Set("privileged", ##class(OcuPilot.Kernel.Proposal.Prohibited).ResourceGrantsAdministrativePrivilege(tName), "boolean")
            Do pResources.%Push(tEntry)
        }
    } Catch ex {
        Set pResources = []
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Every rule this form applies, as <code>[{field, code, reason}]</code>, each field's
/// required-ness rule first. The sentences are
/// <method>OcuPilot.Api.Error.ReasonForViolation</method>'s; a code with no sentence is absent.</p>
ClassMethod Rules() As %DynamicArray
{
    Set tRows = []
    Set tCodes = ##class(OcuPilot.Api.Error).RoleViolationCodes()
    For tI = 1:1:$ListLength(tCodes) {
        Set tCode = $List(tCodes, tI)
        Set tReason = ##class(OcuPilot.Api.Error).ReasonForViolation(tCode)
        If tReason = "" Continue
        Set tRow = {}
        Do tRow.%Set("field", ..FieldOf(tCode), "string")
        Do tRow.%Set("code", tCode, "string")
        Do tRow.%Set("reason", tReason, "string")
        Do tRows.%Push(tRow)
    }
    Quit tRows
}

/// <p>The form field a <code>ROLE.&lt;FIELD&gt;.&lt;RULE&gt;</code> code refuses.</p>
ClassMethod FieldOf(pCode As %String) As %String [ Private ]
{
    Set tPart = $Piece(pCode, ".", 2)
    If tPart = "NAME" Quit ..#FIELDNAME
    If tPart = "DESCRIPTION" Quit ..#FIELDDESCRIPTION
    If tPart = "RESOURCES" Quit ..#FIELDRESOURCES
    If tPart = "GRANTEDROLES" Quit ..#FIELDGRANTEDROLES
    Quit ""
}

/// <p>Refuse a caller who does not hold the form screen's declared pairs (AD-8):
/// <var>pRefused</var> 1 means the envelope is written and the caller writes nothing else.</p>
ClassMethod Gate(Output pRefused As %Boolean) As %Status
{
    Set pRefused = 0
    Set tFailedPair = ""
    If ##class(OcuPilot.Screen.Gate).Evaluate(..#DESCRIPTORCLASS, .tFailedPair) Quit $$$OK
    Set pRefused = 1
    Quit ##class(OcuPilot.Kernel.Denial).Envelope(tFailedPair)
}

/// <p>A comma-separated list as a <class>%DynamicArray</class> of strings.</p>
ClassMethod Names(pList As %String) As %DynamicArray [ Private ]
{
    Set tRows = []
    For tI = 1:1:$Length(pList, ",") {
        Set tName = $Piece(pList, ",", tI)
        If tName '= "" Do tRows.%Push(tName)
    }
    Quit tRows
}

/// <p>Append one <code>(field, code)</code> violation.</p>
ClassMethod Add(Output pViolations, pField As %String, pCode As %String) [ Private ]
{
    Set pViolations($Increment(pViolations)) = $ListBuild(pField, pCode)
}

}

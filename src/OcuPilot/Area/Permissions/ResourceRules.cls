/// <p>The resource editor's rules (AD-39, AD-55): the one rule set every caller of
/// <class>OcuPilot.Screen.Tool.ResourceCreate</class> and <class>OcuPilot.Screen.Tool.ResourceUpdate</class>
/// applies (<method>Validate</method>), the public-permission letters a resource admits
/// (<method>AdmissibleLetters</method>, <method>LetterRules</method>), the editor's form read
/// (<method>HandleForm</method>) and the name look-up (<method>HandleName</method>,
/// <method>Taken</method>).</p>
/// <p><b>Every sentence is <method>OcuPilot.Api.Error.ReasonForViolation</method>'s</b>, and the form
/// read serves the same sentences, so an inline blur refusal and a failed Save are one wording.
/// Whether a public permission on a resource grants privilege is the prohibited set's one
/// classifier (<method>OcuPilot.Kernel.Proposal.Prohibited.ResourceGrantsAdministrativePrivilege</method>),
/// never decided here.</p>
Class OcuPilot.Area.Permissions.ResourceRules Extends %RegisteredObject
{

/// <p>The tools the callers resolve the writes through (AD-55): the create for a name look-up, the
/// update for a present resource's read.</p>
Parameter CREATETOOL = "OcuPilot.Screen.Tool.ResourceCreate";

Parameter UPDATETOOL = "OcuPilot.Screen.Tool.ResourceUpdate";

/// <p>The screen whose declared pairs gate these routes (AD-8).</p>
Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.ResourceList";

/// <p>The fields a create must carry, comma-separated.</p>
Parameter REQUIREDFIELDS = "Name";

/// <p>The longest resource name and description <class>Security.Resources</class> stores: the
/// <code>MAXLEN</code> of its <code>Name</code> and <code>Description</code> properties on this
/// build.</p>
Parameter NAMEMAXLENGTH As INTEGER = 64;

Parameter DESCRIPTIONMAXLENGTH As INTEGER = 256;

/// <p>The characters a resource name may not carry beyond the control characters: the separators
/// <class>Security.Roles</class> keeps a role's resource list in.</p>
Parameter NAMEFORBIDDEN = ",:";

/// <p>The body fields the rules read, named once.</p>
Parameter FIELDNAME = "Name";

Parameter FIELDDESCRIPTION = "Description";

Parameter FIELDPUBLICPERMISSION = "PublicPermission";

/// <p>The rules class the public-permission letters are ported from: the classic resource dialog
/// and the classic role-grant dialog draw their letters from the same <file>%sySecurity.inc</file>
/// prefixes.</p>
Parameter LETTERSOURCE = "OcuPilot.Area.Permissions.RoleCreateRules";

/// <p>Every rule a resource write applies, in <var>pViolations</var> as
/// <code>pViolations(n) = $ListBuild(field, code)</code> with the count in
/// <code>pViolations</code>.</p>
/// <p><var>pCheckName</var> 0 skips the name's own rules, for an edit, whose name is the present
/// resource's; <var>pCheckTaken</var> 0 skips the name look-up, for an edit and for the agent's
/// mint, which has read the target itself. The letters a public permission may carry depend on
/// <var>pName</var> either way.</p>
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
            If tTaken Do ..Add(.pViolations, ..#FIELDNAME, ##class(OcuPilot.Api.Error).#RESOURCENAMETAKEN)
        }
        If '$IsObject(pArgs) Quit

        Set tType = pArgs.%GetTypeOf(..#FIELDDESCRIPTION)
        If (tType = "object") || (tType = "array") {
            Do ..Add(.pViolations, ..#FIELDDESCRIPTION, ##class(OcuPilot.Api.Error).#PORTFIELDSHAPE)
        } ElseIf (tType '= "unassigned") && (tType '= "null") && ($Length(pArgs.%Get(..#FIELDDESCRIPTION)) > ..#DESCRIPTIONMAXLENGTH) {
            Do ..Add(.pViolations, ..#FIELDDESCRIPTION, ##class(OcuPilot.Api.Error).#RESOURCEDESCRIPTIONLENGTH)
        }

        Set tType = pArgs.%GetTypeOf(..#FIELDPUBLICPERMISSION)
        If tType = "unassigned" Quit
        If tType '= "string" {
            Do ..Add(.pViolations, ..#FIELDPUBLICPERMISSION, ##class(OcuPilot.Api.Error).#RESOURCEPUBLICPERMISSIONSHAPE)
            Quit
        }
        Set tLetters = $ZConvert(pArgs.%Get(..#FIELDPUBLICPERMISSION), "U")
        Set tAll = $Parameter(..#LETTERSOURCE, "LETTERS")
        Set tShape = 1
        For tI = 1:1:$Length(tLetters) {
            Set tLetter = $Extract(tLetters, tI)
            If '(tAll [ tLetter) || ($Length(tLetters, tLetter) > 2) Set tShape = 0 Quit
        }
        If 'tShape {
            Do ..Add(.pViolations, ..#FIELDPUBLICPERMISSION, ##class(OcuPilot.Api.Error).#RESOURCEPUBLICPERMISSIONSHAPE)
            Quit
        }
        Set tAdmitted = ..AdmissibleLetters(pName)
        For tI = 1:1:$Length(tLetters) {
            If '(tAdmitted [ $Extract(tLetters, tI)) {
                Do ..Add(.pViolations, ..#FIELDPUBLICPERMISSION, ##class(OcuPilot.Api.Error).#RESOURCEPUBLICPERMISSIONLETTERS)
                Quit
            }
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Add the name's own violation to <var>pViolations</var>, or none: an absent name, one longer
/// than <parameter>NAMEMAXLENGTH</parameter>, and one carrying a control character or a character
/// of <parameter>NAMEFORBIDDEN</parameter>. A name beginning <code>%</code> is admitted, as
/// <class>Security.Resources</class> admits it.</p>
ClassMethod NameViolation(pName As %String, Output pViolations)
{
    If pName = "" {
        Do ..Add(.pViolations, ..#FIELDNAME, ##class(OcuPilot.Api.Error).#RESOURCENAMEREQUIRED)
        Quit
    }
    If $Length(pName) > ..#NAMEMAXLENGTH {
        Do ..Add(.pViolations, ..#FIELDNAME, ##class(OcuPilot.Api.Error).#RESOURCENAMELENGTH)
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
    If 'tUsable Do ..Add(.pViolations, ..#FIELDNAME, ##class(OcuPilot.Api.Error).#RESOURCENAMESHAPE)
}

/// <p>The public-permission letters resource <var>pName</var> admits, in <code>RWU</code> order.
/// Ported from <code>%CSP.UI.Portal.Dialog.Resource</code>: its <code>ShowRead</code> and
/// <code>ShowWrite</code> are 0 for the service, DeepSee, administrative, development, application,
/// system, DocDB, gateway, IAM, native, SQL and secure-shell prefixes, and its <code>ShowUse</code>
/// is 0 for a database's resource -- the same <file>%sySecurity.inc</file> prefixes the classic
/// role-grant dialog draws, so the answer is <parameter>LETTERSOURCE</parameter>'s.</p>
ClassMethod AdmissibleLetters(pName As %String) As %String
{
    Quit $ClassMethod(..#LETTERSOURCE, "AdmissiblePermissions", pName)
}

/// <p><method>AdmissibleLetters</method>'s rule as data, for the editor to apply to a name typed in
/// create mode: <code>{letters, prefixes: [{prefix, letters}]}</code>, where the first prefix a name
/// begins with, compared without regard to case, decides, and <code>letters</code> is the answer for
/// a name that begins with none.</p>
ClassMethod LetterRules() As %DynamicObject
{
    Set tRules = {}
    Do tRules.%Set("letters", $Parameter(..#LETTERSOURCE, "LETTERS"), "string")
    Set tPrefixes = []
    Set tDatabase = $Parameter(..#LETTERSOURCE, "DATABASEPREFIX")
    Do tPrefixes.%Push({"prefix": (tDatabase), "letters": (..AdmissibleLetters(tDatabase))})
    Set tUseOnly = $Parameter(..#LETTERSOURCE, "USEONLYPREFIXES")
    For tI = 1:1:$Length(tUseOnly, ",") {
        Set tPrefix = $Piece(tUseOnly, ",", tI)
        If tPrefix = "" Continue
        Do tPrefixes.%Push({"prefix": (tPrefix), "letters": (..AdmissibleLetters(tPrefix))})
    }
    Do tRules.%Set("prefixes", tPrefixes)
    Quit tRules
}

/// <p>Answer <code>GET /resources/form[?name=&lt;n&gt;]</code>: everything the editor needs before it
/// can draw a field (AD-39): <code>{requiredFields, maxLengths, rules, letterRules}</code>. With a
/// name it adds <code>resource: {name, Description, PublicPermission, privileged}</code>, the
/// resource as the update tool's own port reads it, where <code>privileged</code> is whether a
/// public permission on it grants an administrative privilege; a name this instance does not hold
/// is 404 <parameter>OcuPilot.Api.Error.RESOURCENAMEABSENT</parameter>.</p>
ClassMethod HandleForm() As %Status
{
    Set tSC = $$$OK
    Try {
        Set tGateSC = ..Gate(.tRefused)
        If tRefused || $$$ISERR(tGateSC) {
            Set tSC = tGateSC
            Quit
        }
        Set tBody = {}
        Do tBody.%Set("requiredFields", [(..#REQUIREDFIELDS)])
        Set tLengths = {}
        Do tLengths.%Set(..#FIELDNAME, ..#NAMEMAXLENGTH, "number")
        Do tLengths.%Set(..#FIELDDESCRIPTION, ..#DESCRIPTIONMAXLENGTH, "number")
        Do tBody.%Set("maxLengths", tLengths)
        Do tBody.%Set("rules", ..Rules())
        Do tBody.%Set("letterRules", ..LetterRules())
        Set tName = $Get(%request.Data("name", 1))
        If tName '= "" {
            Set tReadSC = ..Present(tName, .tFresh, .tHttp, .tFault)
            If $$$ISERR(tReadSC) {
                Set tSC = ..RenderRead(tReadSC, tHttp, tFault)
                Quit
            }
            Set tResource = {}
            Do tResource.%Set("name", tName, "string")
            Do tResource.%Set(..#FIELDDESCRIPTION, tFresh.%Get(..#FIELDDESCRIPTION), "string")
            Do tResource.%Set(..#FIELDPUBLICPERMISSION, tFresh.%Get(..#FIELDPUBLICPERMISSION), "string")
            Do tResource.%Set("privileged", ##class(OcuPilot.Kernel.Proposal.Prohibited).ResourceGrantsAdministrativePrivilege(tName), "boolean")
            Do tBody.%Set("resource", tResource)
        }
        Set tSC = ##class(OcuPilot.Api.Response).JSON(tBody)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>Answer <code>GET /resources/name?name=&lt;n&gt;</code>: whether that name is taken and whether
/// a public permission on it grants an administrative privilege, in
/// <code>{name, taken, reason, privileged}</code>. A look-up that cannot be made is a refusal
/// envelope, never an assertion that the name is free.</p>
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
            Set tSC = ##class(OcuPilot.Area.Permissions.ResourceSave).RenderOne(..#FIELDNAME, ##class(OcuPilot.Api.Error).#RESOURCENAMEREQUIRED)
            Quit
        }
        Set tTakenSC = ..Taken(tName, .tTaken)
        If $$$ISERR(tTakenSC) {
            Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tTakenSC))
            Quit
        }
        Set tBody = {}
        Do tBody.%Set("name", tName, "string")
        Do tBody.%Set("taken", tTaken, "boolean")
        Do tBody.%Set("reason", $Select(tTaken: ##class(OcuPilot.Api.Error).ReasonForViolation(##class(OcuPilot.Api.Error).#RESOURCENAMETAKEN), 1: ""), "string")
        Do tBody.%Set("privileged", ##class(OcuPilot.Kernel.Proposal.Prohibited).ResourceGrantsAdministrativePrivilege(tName), "boolean")
        Set tSC = ##class(OcuPilot.Api.Response).JSON(tBody)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>Whether a resource already carries <var>pName</var>, in <var>pTaken</var>, read through the
/// create tool's own port, endpoint and read type (AD-52). A resource name is compared without
/// regard to case, so the read answers for a name in any case.</p>
/// <p><b>Caller contract:</b> an error status means the question was not answered; only a 404 is
/// "free".</p>
ClassMethod Taken(pName As %String, Output pTaken As %Boolean) As %Status
{
    Set pTaken = 0
    Set tSC = ..Read(..#CREATETOOL, pName, .tFresh, .tHttp, .tFault)
    If $$$ISERR(tSC) {
        If +$Get(tHttp) = 404 Quit $$$OK
        Quit tSC
    }
    Set pTaken = ($IsObject(tFresh) && tFresh.%IsA("%Library.DynamicObject"))
    Quit $$$OK
}

/// <p>The present resource <var>pName</var>, read through the update tool's own port, endpoint and
/// read type (AD-52), in <var>pFresh</var>. An absent one is an error status with
/// <var>pHttpStatus</var> 404.</p>
ClassMethod Present(pName As %String, Output pFresh As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set tSC = ..Read(..#UPDATETOOL, pName, .pFresh, .pHttpStatus, .pFault)
    If $$$ISOK(tSC) && '($IsObject(pFresh) && pFresh.%IsA("%Library.DynamicObject")) {
        Set pHttpStatus = 404
        Set tSC = $$$ERROR($$$GeneralError, ##class(OcuPilot.Api.Error).#RESOURCENAMEABSENT)
    }
    Quit tSC
}

/// <p>Render a failed <method>Present</method> read: a 404 as
/// <parameter>OcuPilot.Api.Error.RESOURCENAMEABSENT</parameter>, any other refusal as the port's own
/// envelope, and an internal failure generically.</p>
ClassMethod RenderRead(pSC As %Status, pHttpStatus As %Integer, pFault As %DynamicObject) As %Status
{
    If +$Get(pHttpStatus) = 404 {
        Quit ##class(OcuPilot.Api.Error).Render(404, ##class(OcuPilot.Api.Error).#NOTFOUND, ##class(OcuPilot.Api.Error).#REASONRESOURCENAMEABSENT, ##class(OcuPilot.Api.Error).#RESOURCENAMEABSENT)
    }
    If '$IsObject($Get(pFault)) || (pFault.code = ##class(OcuPilot.Api.Error).#INTERNAL) {
        Quit ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(pSC))
    }
    Quit ##class(OcuPilot.Api.Error).Render($Select(+$Get(pHttpStatus): +pHttpStatus, 1: 500), pFault.error, pFault.reason, pFault.code, pFault.%Get("detail"))
}

/// <p>Read <var>pName</var> through tool <var>pToolClass</var>'s own port, endpoint and read
/// type.</p>
ClassMethod Read(pToolClass As %String, pName As %String, Output pFresh As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pFresh = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Set tSC = $$$OK
    Try {
        Kill tQuery
        Set tQuery($ClassMethod(pToolClass, "IdParam")) = pName
        Set tSC = $ClassMethod($ClassMethod(pToolClass, "PortClass"), "Invoke", $ClassMethod(pToolClass, "Endpoint"), $ClassMethod(pToolClass, "ReadType"), .tQuery, "", .pFresh, .pHttpStatus, .pFault)
    } Catch ex {
        Set pFresh = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Every rule this editor applies, as <code>[{field, code, reason}]</code>. The sentences are
/// <method>OcuPilot.Api.Error.ReasonForViolation</method>'s; a code with no sentence is absent.</p>
ClassMethod Rules() As %DynamicArray
{
    Set tRows = []
    Set tCodes = ##class(OcuPilot.Api.Error).ResourceViolationCodes()
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

/// <p>The editor field a <code>RESOURCE.&lt;FIELD&gt;.&lt;RULE&gt;</code> code refuses.</p>
ClassMethod FieldOf(pCode As %String) As %String [ Private ]
{
    Set tPart = $Piece(pCode, ".", 2)
    If tPart = "NAME" Quit ..#FIELDNAME
    If tPart = "DESCRIPTION" Quit ..#FIELDDESCRIPTION
    If tPart = "PUBLICPERMISSION" Quit ..#FIELDPUBLICPERMISSION
    Quit ""
}

/// <p>Refuse a caller who does not hold the Resources list's declared pairs (AD-8):
/// <var>pRefused</var> 1 means the envelope is written and the caller writes nothing else.</p>
ClassMethod Gate(Output pRefused As %Boolean) As %Status
{
    Set pRefused = 0
    Set tFailedPair = ""
    If ##class(OcuPilot.Screen.Gate).Evaluate(..#DESCRIPTORCLASS, .tFailedPair) Quit $$$OK
    Set pRefused = 1
    Quit ##class(OcuPilot.Kernel.Denial).Envelope(tFailedPair)
}

/// <p>Append one <code>(field, code)</code> violation.</p>
ClassMethod Add(Output pViolations, pField As %String, pCode As %String) [ Private ]
{
    Set pViolations($Increment(pViolations)) = $ListBuild(pField, pCode)
}

}

/// <p>The service form's rules (AD-39, AD-55): the one rule set <class>OcuPilot.Screen.Tool.ServiceUpdate</class>'s
/// mint and <class>OcuPilot.Area.Permissions.ServiceSave</class>'s Save apply (<method>Validate</method>),
/// and the form's read (<method>HandleForm</method>).</p>
/// <p><b>Every sentence is <method>OcuPilot.Api.Error.ReasonForViolation</method>'s.</b> Each rule
/// refuses a value the vendor would accept and misread (measured on this build): an entry holding a
/// semicolon is split into two, a role the instance does not hold is stored as named, and an
/// authentication method outside the service's own capabilities is masked away with a 200.</p>
Class OcuPilot.Area.Permissions.ServiceRules Extends %RegisteredObject
{

/// <p>The tool both callers resolve the write through (AD-55).</p>
Parameter UPDATETOOL = "OcuPilot.Screen.Tool.ServiceUpdate";

/// <p>The screen whose declared pairs gate the routes (AD-8).</p>
Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.ServiceForm";

/// <p>The fields a change may set, comma-separated: the tool's <parameter>OcuPilot.Screen.Tool.ServiceUpdate.PERMITTEDFIELDS</parameter>.</p>
Parameter FIELDS = "AutheEnabled,ClientSystems,Enabled";

Parameter FIELDAUTHE = "AutheEnabled";

Parameter FIELDCLIENTSYSTEMS = "ClientSystems";

Parameter FIELDENABLED = "Enabled";

/// <p>Every rule a service change applies to the fields <var>pArgs</var> carries, read against the
/// service <var>pName</var> whose fresh read is <var>pFresh</var>, in <var>pViolations</var> as
/// <code>pViolations(n) = $ListBuild(field, code)</code> with the count in
/// <code>pViolations</code>.</p>
/// <p><code>Enabled</code> is a boolean; <code>ClientSystems</code> an array of entries, each
/// <code>address</code> or <code>address|role,role</code> with no whitespace or semicolon
/// (<parameter>OcuPilot.Api.Error.SERVICEADDRESSSHAPE</parameter>) and every role one
/// <class>Security.Roles</class> holds (<parameter>OcuPilot.Api.Error.SERVICEADDRESSROLE</parameter>);
/// <code>AutheEnabled</code> a whole number whose every bit the service's own
/// <code>AutheEnabledCapabilities</code> carries
/// (<parameter>OcuPilot.Api.Error.SERVICEAUTHEUNSUPPORTED</parameter>), read in <code>%SYS</code>
/// (AD-16) and skipped for a service the instance does not hold.</p>
ClassMethod Validate(pName As %String, pArgs As %DynamicObject, pFresh As %DynamicObject, Output pViolations) As %Status
{
    Kill pViolations
    Set pViolations = 0
    Set tSC = $$$OK
    Try {
        If '$IsObject(pArgs) Quit
        Set tType = pArgs.%GetTypeOf(..#FIELDENABLED)
        If (tType '= "unassigned") && (tType '= "boolean") {
            If '((tType = "number") && ((pArgs.%Get(..#FIELDENABLED) = 0) || (pArgs.%Get(..#FIELDENABLED) = 1))) {
                Do ..Add(.pViolations, ..#FIELDENABLED, ##class(OcuPilot.Api.Error).#PORTFIELDSHAPE)
            }
        }

        Set tType = pArgs.%GetTypeOf(..#FIELDCLIENTSYSTEMS)
        If tType = "array" {
            Set tSC = ..AddressViolations(pArgs.%Get(..#FIELDCLIENTSYSTEMS), .pViolations)
            If $$$ISERR(tSC) Quit
        } ElseIf tType '= "unassigned" {
            Do ..Add(.pViolations, ..#FIELDCLIENTSYSTEMS, ##class(OcuPilot.Api.Error).#PORTFIELDSHAPE)
        }

        Set tType = pArgs.%GetTypeOf(..#FIELDAUTHE)
        If tType '= "unassigned" {
            Set tValue = pArgs.%Get(..#FIELDAUTHE)
            If ((tType '= "number") && (tType '= "string")) || '$IsValidNum(tValue) || (+tValue '= (tValue \ 1)) || (+tValue < 0) {
                Do ..Add(.pViolations, ..#FIELDAUTHE, ##class(OcuPilot.Api.Error).#PORTFIELDSHAPE)
            } ElseIf $IsObject(pFresh) {
                Set tSC = ..Capabilities(pName, .tCapabilities, .tRead)
                If $$$ISERR(tSC) Quit
                If tRead && ..Outside(+tValue, tCapabilities) {
                    Do ..Add(.pViolations, ..#FIELDAUTHE, ##class(OcuPilot.Api.Error).#SERVICEAUTHEUNSUPPORTED)
                }
            }
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Add the address rules' violations for the entries of <var>pEntries</var>: at most one
/// <parameter>OcuPilot.Api.Error.SERVICEADDRESSSHAPE</parameter> and one
/// <parameter>OcuPilot.Api.Error.SERVICEADDRESSROLE</parameter>, both on
/// <code>ClientSystems</code>.</p>
ClassMethod AddressViolations(pEntries As %DynamicArray, ByRef pViolations) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set (tType, tShape, tUnknown) = 0
    Kill tRoles
    Set tIterator = pEntries.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tEntry) {
        If $IsObject(tEntry) || (pEntries.%GetTypeOf(tIndex) '= "string") {
            Set tType = 1
            Continue
        }
        If '..EntryShaped(tEntry) {
            Set tShape = 1
            Continue
        }
        Set tList = $Piece(tEntry, "|", 2)
        For tI = 1:1:$Length(tList, ",") {
            Set tRole = $Piece(tList, ",", tI)
            If tRole '= "" Set tRoles($ZConvert(tRole, "U")) = tRole
        }
    }
    If tType Do ..Add(.pViolations, ..#FIELDCLIENTSYSTEMS, ##class(OcuPilot.Api.Error).#PORTFIELDSHAPE)
    If tShape Do ..Add(.pViolations, ..#FIELDCLIENTSYSTEMS, ##class(OcuPilot.Api.Error).#SERVICEADDRESSSHAPE)
    If $Data(tRoles) {
        Set tOrigNS = $NAMESPACE
        Try {
            Set $NAMESPACE = "%SYS"
            Set tKey = ""
            For {
                Set tKey = $Order(tRoles(tKey))
                If tKey = "" Quit
                If '##class(Security.Roles).Exists(tRoles(tKey)) Set tUnknown = 1 Quit
            }
            Set $NAMESPACE = tOrigNS
        } Catch ex {
            Set $NAMESPACE = tOrigNS
            Set tSC = ex.AsStatus()
        }
        If $$$ISERR(tSC) Quit tSC
    }
    If tUnknown Do ..Add(.pViolations, ..#FIELDCLIENTSYSTEMS, ##class(OcuPilot.Api.Error).#SERVICEADDRESSROLE)
    Quit tSC
}

/// <p>Whether <var>pEntry</var> is one allowed connection the vendor stores as one: an address, with
/// at most one <code>|</code> followed by a comma-separated role list, and no whitespace or
/// semicolon anywhere. An empty address, an empty role list after a <code>|</code> and an empty
/// role between commas are all refused. A shape refusal is
/// <parameter>OcuPilot.Api.Error.SERVICEADDRESSSHAPE</parameter>'s, which is why this answers no
/// code of its own.</p>
ClassMethod EntryShaped(pEntry As %String) As %Boolean
{
    If pEntry = "" Quit 0
    If pEntry [ ";" Quit 0
    If $Translate(pEntry, " " _ $Char(9, 10, 13, 160)) '= pEntry Quit 0
    If $Length(pEntry, "|") > 2 Quit 0
    If $Piece(pEntry, "|", 1) = "" Quit 0
    If pEntry '[ "|" Quit 1
    Set tList = $Piece(pEntry, "|", 2)
    If tList = "" Quit 0
    For tI = 1:1:$Length(tList, ",") {
        If $Piece(tList, ",", tI) = "" Quit
    }
    Quit ($Piece(tList, ",", tI) '= "")
}

/// <p>The service <var>pName</var>'s <code>AutheEnabledCapabilities</code> mask, read in
/// <code>%SYS</code> (AD-16), in <var>pCapabilities</var>; <var>pRead</var> 0 when the service is
/// not held, which leaves the rule unjudged.</p>
ClassMethod Capabilities(pName As %String, Output pCapabilities As %Integer, Output pRead As %Boolean) As %Status
{
    Set pCapabilities = 0
    Set pRead = 0
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Kill tProperties
        Set tGetSC = ##class(Security.Services).Get(pName, .tProperties)
        Set $NAMESPACE = tOrigNS
        If $$$ISERR(tGetSC) Quit
        Set pCapabilities = +$Get(tProperties("AutheEnabledCapabilities"))
        Set pRead = 1
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Whether <var>pMask</var> sets a bit <var>pCapabilities</var> does not.</p>
ClassMethod Outside(pMask As %Integer, pCapabilities As %Integer) As %Boolean
{
    Set tMask = pMask
    Set tCaps = pCapabilities
    While tMask > 0 {
        If (tMask # 2) && '(tCaps # 2) Quit
        Set tMask = tMask \ 2
        Set tCaps = tCaps \ 2
    }
    Quit (tMask > 0)
}

/// <p>The members of <var>pArgs</var> among <parameter>FIELDS</parameter> whose value differs from
/// <var>pFresh</var>'s, compared in the diff's rendered form, as a new
/// <class>%DynamicObject</class>. Every carried one is kept when there is no fresh read.</p>
ClassMethod Changed(pArgs As %DynamicObject, pFresh As %DynamicObject = "") As %DynamicObject
{
    Set tChanged = {}
    If '$IsObject(pArgs) Quit tChanged
    For tI = 1:1:$Length(..#FIELDS, ",") {
        Set tField = $Piece(..#FIELDS, ",", tI)
        Set tType = pArgs.%GetTypeOf(tField)
        If tType = "unassigned" Continue
        If $IsObject(pFresh) && (pFresh.%GetTypeOf(tField) '= "unassigned") {
            Set tBefore = ##class(OcuPilot.Kernel.Proposal.Mint).Display(pFresh.%Get(tField), pFresh.%GetTypeOf(tField))
            Set tAfter = ##class(OcuPilot.Kernel.Proposal.Mint).Display(pArgs.%Get(tField), tType)
            If tAfter = tBefore Continue
        }
        If (tType = "object") || (tType = "array") {
            Do tChanged.%Set(tField, pArgs.%Get(tField))
        } Else {
            Do tChanged.%Set(tField, pArgs.%Get(tField), tType)
        }
    }
    Quit tChanged
}

/// <p><var>pViolations</var> as one problem sentence naming each field and its published sentence,
/// or <code>""</code> for none: what the tool's <code>ArgumentProblem</code> answers.</p>
ClassMethod Problem(ByRef pViolations) As %String
{
    Set tProblem = ""
    For tI = 1:1:$Get(pViolations) {
        Set tReason = ##class(OcuPilot.Api.Error).ReasonForViolation($List(pViolations(tI), 2))
        Set tProblem = tProblem _ $Select(tProblem = "": "", 1: " ") _ "'" _ $List(pViolations(tI), 1) _ "': " _ tReason
    }
    Quit tProblem
}

/// <p>Answer <code>GET /services/form?name=&lt;n&gt;</code>: <code>{service, servesOcuPilot}</code>,
/// the service being the change tool's fresh read with its <code>Name</code>, and
/// <code>servesOcuPilot</code> whether it is the service OcuPilot is served through
/// (<method>OcuPilot.Kernel.Proposal.Prohibited.IsServingService</method>). A name this instance does
/// not hold, or none, is 404 <parameter>OcuPilot.Api.Error.SERVICEABSENT</parameter>.</p>
ClassMethod HandleForm() As %Status
{
    Set tSC = $$$OK
    Try {
        Set tGateSC = ..Gate(.tRefused)
        If tRefused || $$$ISERR(tGateSC) {
            Set tSC = tGateSC
            Quit
        }
        Set tName = $Get(%request.Data("name", 1))
        Set tReadSC = ..Present(tName, .tFresh, .tHttp, .tFault)
        If $$$ISERR(tReadSC) {
            Set tSC = ..RenderRead(tReadSC, tHttp, tFault)
            Quit
        }
        Set tService = {}
        Do tService.%Set("Name", tName, "string")
        Set tIterator = tFresh.%GetIterator()
        While tIterator.%GetNext(.tKey, .tValue) {
            Set tType = tFresh.%GetTypeOf(tKey)
            If (tType = "object") || (tType = "array") {
                Do tService.%Set(tKey, tValue)
            } Else {
                Do tService.%Set(tKey, tValue, tType)
            }
        }
        Set tBody = {}
        Do tBody.%Set("service", tService)
        Do tBody.%Set("servesOcuPilot", ##class(OcuPilot.Kernel.Proposal.Prohibited).IsServingService(tName), "boolean")
        Set tSC = ##class(OcuPilot.Api.Response).JSON(tBody)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>The service <var>pName</var>, read through the change tool's own port, endpoint and read type
/// (AD-52), in <var>pFresh</var>. An absent or empty name is an error status with
/// <var>pHttpStatus</var> 404.</p>
ClassMethod Present(pName As %String, Output pFresh As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pFresh = ""
    Set pHttpStatus = 0
    Set pFault = ""
    If pName = "" {
        Set pHttpStatus = 404
        Quit $$$ERROR($$$GeneralError, ##class(OcuPilot.Api.Error).#SERVICEABSENT)
    }
    Set tSC = $$$OK
    Try {
        Set tClass = ..#UPDATETOOL
        Kill tQuery
        Set tQuery($ClassMethod(tClass, "IdParam")) = pName
        Set tSC = $ClassMethod($ClassMethod(tClass, "PortClass"), "Invoke", $ClassMethod(tClass, "Endpoint"), $ClassMethod(tClass, "ReadType"), .tQuery, "", .pFresh, .pHttpStatus, .pFault)
    } Catch ex {
        Set pFresh = ""
        Set tSC = ex.AsStatus()
    }
    If $$$ISOK(tSC) && '($IsObject(pFresh) && pFresh.%IsA("%Library.DynamicObject")) {
        Set pHttpStatus = 404
        Set tSC = $$$ERROR($$$GeneralError, ##class(OcuPilot.Api.Error).#SERVICEABSENT)
    }
    Quit tSC
}

/// <p>Render a failed read: a 404 as <parameter>OcuPilot.Api.Error.SERVICEABSENT</parameter>, any
/// other refusal as the port's own envelope, and an internal failure generically.</p>
ClassMethod RenderRead(pSC As %Status, pHttpStatus As %Integer, pFault As %DynamicObject) As %Status
{
    If +$Get(pHttpStatus) = 404 {
        Quit ##class(OcuPilot.Api.Error).Render(404, ##class(OcuPilot.Api.Error).#NOTFOUND, ##class(OcuPilot.Api.Error).#REASONSERVICEABSENT, ##class(OcuPilot.Api.Error).#SERVICEABSENT)
    }
    If '$IsObject($Get(pFault)) || (pFault.code = ##class(OcuPilot.Api.Error).#INTERNAL) {
        Quit ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(pSC))
    }
    Quit ##class(OcuPilot.Api.Error).Render($Select(+$Get(pHttpStatus): +pHttpStatus, 1: 500), pFault.error, pFault.reason, pFault.code, pFault.%Get("detail"))
}

/// <p>Refuse a caller who does not hold the form's declared pairs (AD-8): <var>pRefused</var> 1
/// means the envelope is written and the caller writes nothing else.</p>
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

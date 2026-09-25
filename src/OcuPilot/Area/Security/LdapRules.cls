/// <p>The LDAP configuration form's rules (AD-39, AD-55): the one rule set
/// <class>OcuPilot.Screen.Tool.LdapUpdate</class>'s mint and
/// <class>OcuPilot.Area.Security.LdapSave</class>'s Save apply (<method>Validate</method>), and the
/// form's read (<method>HandleForm</method>).</p>
/// <p><b>Every sentence is <method>OcuPilot.Api.Error.ReasonForViolation</method>'s.</b> The rules
/// refuse what the vendor would store wrongly or refuse late: an empty value for a setting
/// <class>Security.LDAPConfigs</class> declares <code>Required</code>, a host entry the vendor's
/// space-joined host list would split or lose, flags outside the eight declared bits, and a
/// description past the class's own bound.</p>
Class OcuPilot.Area.Security.LdapRules Extends %RegisteredObject
{

/// <p>The tool both callers resolve the write through (AD-55).</p>
Parameter UPDATETOOL = "OcuPilot.Screen.Tool.LdapUpdate";

/// <p>The screen whose declared pairs gate the routes (AD-8).</p>
Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.LdapConfigForm";

/// <p>The vendor class whose property declarations the required rule reads, in <code>%SYS</code>.</p>
Parameter CONFIGCLASS = "Security.LDAPConfigs";

/// <p>The <code>MAXLEN</code> of <class>Security.LDAPConfigs</class>'s <code>Description</code>.</p>
Parameter DESCRIPTIONMAXLENGTH As INTEGER = 128;

/// <p>The largest <code>LDAPFlags</code> value: bits 0 to 7, as <class>Security.LDAPConfigs</class>
/// documents them.</p>
Parameter FLAGSMAX As INTEGER = 255;

/// <p>The two list fields, each an array of strings.</p>
Parameter LISTFIELDS = "LDAPAttributes,LDAPHostNames";

/// <p>The three whole-number fields.</p>
Parameter NUMBERFIELDS = "LDAPClientTimeout,LDAPFlags,LDAPServerTimeout";

Parameter FIELDDESCRIPTION = "Description";

Parameter FIELDFLAGS = "LDAPFlags";

Parameter FIELDHOSTS = "LDAPHostNames";

/// <p>Every rule an LDAP configuration change applies to the fields <var>pArgs</var> carries, in
/// <var>pViolations</var> as <code>pViolations(n) = $ListBuild(field, code)</code> with the count in
/// <code>pViolations</code>. <var>pName</var> and <var>pFresh</var> are the target and its fresh
/// read; no rule reads them today.</p>
ClassMethod Validate(pName As %String, pArgs As %DynamicObject, pFresh As %DynamicObject, Output pViolations) As %Status
{
    Kill pViolations
    Set pViolations = 0
    Set tSC = $$$OK
    Try {
        If '$IsObject(pArgs) Quit
        Set tFields = ##class(OcuPilot.Kernel.Proposal.Prohibited).LdapFields()
        For tI = 1:1:$ListLength(tFields) {
            Set tField = $List(tFields, tI)
            Set tType = pArgs.%GetTypeOf(tField)
            If tType = "unassigned" Continue
            Set tValue = pArgs.%Get(tField)
            If $ListFind($ListFromString(..#LISTFIELDS), tField) {
                Set tSC = ..ListViolation(tField, pArgs, .pViolations)
                If $$$ISERR(tSC) Quit
                Continue
            }
            If (tType = "object") || (tType = "array") || (tType = "null") {
                Do ..Add(.pViolations, tField, ##class(OcuPilot.Api.Error).#PORTFIELDSHAPE)
                Continue
            }
            If $ZStrip(tValue, "<>W") = "" {
                Set tSC = ..Required(tField, .tRequired)
                If $$$ISERR(tSC) Quit
                If tRequired {
                    Do ..Add(.pViolations, tField, ##class(OcuPilot.Api.Error).#LDAPFIELDREQUIRED)
                    Continue
                }
            }
            If tField = ..#FIELDFLAGS {
                If '..WholeIn(tValue, 0, ..#FLAGSMAX) Do ..Add(.pViolations, tField, ##class(OcuPilot.Api.Error).#LDAPFLAGSVALUE)
                Continue
            }
            If $ListFind($ListFromString(..#NUMBERFIELDS), tField) {
                If (tValue '= "") && '..WholeIn(tValue, 0, 2147483647) Do ..Add(.pViolations, tField, ##class(OcuPilot.Api.Error).#PORTFIELDSHAPE)
                Continue
            }
            If (tField = ..#FIELDDESCRIPTION) && ($Length(tValue) > ..#DESCRIPTIONMAXLENGTH) {
                Do ..Add(.pViolations, tField, ##class(OcuPilot.Api.Error).#LDAPDESCRIPTIONLENGTH)
            }
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Add the list field <var>pField</var>'s violation, or none: an array of strings, and for the
/// host names every entry one name with no whitespace
/// (<parameter>OcuPilot.Api.Error.LDAPHOSTSHAPE</parameter>), because the vendor joins the entries
/// with a space.</p>
ClassMethod ListViolation(pField As %String, pArgs As %DynamicObject, ByRef pViolations) As %Status [ Private ]
{
    If pArgs.%GetTypeOf(pField) '= "array" {
        Do ..Add(.pViolations, pField, ##class(OcuPilot.Api.Error).#PORTFIELDSHAPE)
        Quit $$$OK
    }
    Set tEntries = pArgs.%Get(pField)
    Set (tType, tShape) = 0
    Set tIterator = tEntries.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tEntry) {
        If $IsObject(tEntry) || (tEntries.%GetTypeOf(tIndex) '= "string") {
            Set tType = 1
            Continue
        }
        If pField '= ..#FIELDHOSTS Continue
        If (tEntry = "") || ($Translate(tEntry, " " _ $Char(9, 10, 13, 160)) '= tEntry) Set tShape = 1
    }
    If tType Do ..Add(.pViolations, pField, ##class(OcuPilot.Api.Error).#PORTFIELDSHAPE)
    If tShape Do ..Add(.pViolations, pField, ##class(OcuPilot.Api.Error).#LDAPHOSTSHAPE)
    Quit $$$OK
}

/// <p>Whether <parameter>CONFIGCLASS</parameter> declares <var>pField</var> <code>Required</code>, in
/// <var>pRequired</var>, read from its compiled declaration in <code>%SYS</code> (AD-16). A property
/// the class does not declare is not required.</p>
ClassMethod Required(pField As %String, Output pRequired As %Boolean) As %Status
{
    Set pRequired = 0
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tProperty = ##class(%Dictionary.CompiledProperty).%OpenId(..#CONFIGCLASS _ "||" _ pField, 0)
        If $IsObject(tProperty) Set pRequired = ''tProperty.Required
        Set tProperty = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Whether <var>pValue</var> is a whole number from <var>pLow</var> to <var>pHigh</var>.</p>
ClassMethod WholeIn(pValue As %String, pLow As %Integer, pHigh As %Integer) As %Boolean
{
    If '$IsValidNum(pValue) Quit 0
    If +pValue '= (pValue \ 1) Quit 0
    Quit (+pValue >= pLow) && (+pValue <= pHigh)
}

/// <p>The members of <var>pArgs</var> among the settable fields
/// (<method>OcuPilot.Kernel.Proposal.Prohibited.LdapFields</method>) whose value differs from
/// <var>pFresh</var>'s, compared in the diff's rendered form, as a new
/// <class>%DynamicObject</class>. Every carried one is kept when there is no fresh read.</p>
ClassMethod Changed(pArgs As %DynamicObject, pFresh As %DynamicObject = "") As %DynamicObject
{
    Set tChanged = {}
    If '$IsObject(pArgs) Quit tChanged
    Set tFields = ##class(OcuPilot.Kernel.Proposal.Prohibited).LdapFields()
    For tI = 1:1:$ListLength(tFields) {
        Set tField = $List(tFields, tI)
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

/// <p>Answer <code>GET /ldap/form?name=&lt;n&gt;</code>: <code>{ldap}</code>, the change tool's
/// fresh read with its <code>Name</code>. The vendor's read carries no search password. A name this
/// instance does not hold, or none, is 404 <parameter>OcuPilot.Api.Error.LDAPABSENT</parameter>.</p>
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
        Set tLdap = {}
        Do tLdap.%Set("Name", tName, "string")
        Set tIterator = tFresh.%GetIterator()
        While tIterator.%GetNext(.tKey, .tValue) {
            Set tType = tFresh.%GetTypeOf(tKey)
            If (tType = "object") || (tType = "array") {
                Do tLdap.%Set(tKey, tValue)
            } Else {
                Do tLdap.%Set(tKey, tValue, tType)
            }
        }
        Set tBody = {}
        Do tBody.%Set("ldap", tLdap)
        Set tSC = ##class(OcuPilot.Api.Response).JSON(tBody)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>The LDAP configuration <var>pName</var>, read through the change tool's own port, endpoint and
/// read type (AD-52), in <var>pFresh</var>. An absent or empty name is an error status with
/// <var>pHttpStatus</var> 404.</p>
ClassMethod Present(pName As %String, Output pFresh As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pFresh = ""
    Set pHttpStatus = 0
    Set pFault = ""
    If pName = "" {
        Set pHttpStatus = 404
        Quit $$$ERROR($$$GeneralError, ##class(OcuPilot.Api.Error).#LDAPABSENT)
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
        Set tSC = $$$ERROR($$$GeneralError, ##class(OcuPilot.Api.Error).#LDAPABSENT)
    }
    Quit tSC
}

/// <p>Render a failed read: a 404 as <parameter>OcuPilot.Api.Error.LDAPABSENT</parameter>, any other
/// refusal as the port's own envelope, and an internal failure generically.</p>
ClassMethod RenderRead(pSC As %Status, pHttpStatus As %Integer, pFault As %DynamicObject) As %Status
{
    If +$Get(pHttpStatus) = 404 {
        Quit ##class(OcuPilot.Api.Error).Render(404, ##class(OcuPilot.Api.Error).#NOTFOUND, ##class(OcuPilot.Api.Error).#REASONLDAPABSENT, ##class(OcuPilot.Api.Error).#LDAPABSENT)
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

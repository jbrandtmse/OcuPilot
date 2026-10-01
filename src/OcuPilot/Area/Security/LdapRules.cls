/// <p>The LDAP and Kerberos editor's rules (AD-39, AD-55): the one rule set the LDAP tools' mints and
/// <class>OcuPilot.Area.Security.LdapSave</class>'s Saves apply (<method>Validate</method>,
/// <method>NameViolation</method>), the complete body a create sends (<method>Compose</method>), and
/// the editor's reads: the form (<method>HandleForm</method>), the name check
/// (<method>HandleName</method>), the group examples (<method>HandleExamples</method>) and Test
/// authentication (<method>HandleTest</method>).</p>
/// <p><b>Every sentence is <method>OcuPilot.Api.Error.ReasonForViolation</method>'s.</b> The rules
/// refuse what the vendor would store wrongly or refuse late: an empty value for a setting
/// <class>Security.LDAPConfigs</class> declares <code>Required</code>, a host entry the vendor's
/// space-joined host list would split or lose, flags outside the eight declared bits or carrying both
/// enabled and Kerberos-only, no host on an LDAP configuration, a description past the class's own
/// bound, and a name the instance would store differently.</p>
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

Parameter FIELDNAME = "Name";

Parameter FIELDUSER = "LDAPSearchUsername";

/// <p>The create tool the name check and the create's absence read go through (AD-52, AD-54).</p>
Parameter CREATETOOL = "OcuPilot.Screen.Tool.LdapCreate";

/// <p><code>LDAPFlags</code>' enabled bit (<code>$$$LDAPEnabled</code>).</p>
Parameter FLAGENABLED As INTEGER = 64;

/// <p><code>LDAPFlags</code>' Kerberos-only bit (<code>$$$LDAPKerberosOnly</code>). The instance
/// clears the enabled bit whenever it is set (measured: 192 is stored as 128).</p>
Parameter FLAGKERBEROSONLY As INTEGER = 128;

/// <p><class>Security.System</class>'s <code>AutheEnabled</code> bit for Kerberos
/// (<code>$$$AutheKB</code>), which decides whether the editor draws the Kerberos pair.</p>
Parameter AUTHEKERBEROS As INTEGER = 128;

/// <p>The host and search user a Kerberos-only configuration is stored with when it names none: the
/// classic page's own values (<code>%CSP.UI.Portal.LDAP</code>'s <code>doSave</code>).</p>
Parameter UNKNOWNHOST = "UNKNOWNHOST";

Parameter UNKNOWNUSER = "UNKNOWNUSER";

/// <p>The classic Test LDAP Authentication page, whose custom resource the test route unions
/// (AD-44).</p>
Parameter TESTPAGE = "%CSP.UI.Portal.LDAPTest";

/// <p>The group inputs <code>GET /ldap/examples</code> reads, in
/// <code>Security.LDAPConfigs.FormatExample</code>'s argument order after its mode.</p>
Parameter EXAMPLEINPUTS = "OrganizationId,GroupId,InstanceId,RoleId,EscalationRoleId,NamespaceId,RoutineId,DelimiterId,UniversalGroup,LDAPGroupId,LDAPInstanceId";

/// <p>The two keys a test of authentication's body carries.</p>
Parameter TESTUSER = "Username";

Parameter TESTPASSWORD = "Password";

/// <p>Every rule an LDAP configuration change applies to the fields <var>pArgs</var> carries, in
/// <var>pViolations</var> as <code>pViolations(n) = $ListBuild(field, code)</code> with the count in
/// <code>pViolations</code>. <var>pName</var> is the target; <var>pFresh</var> is its fresh read, or
/// a create's <method>Defaults</method>, from which the host rule reads the flags and hosts the
/// arguments do not carry.</p>
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
        If $$$ISERR(tSC) Quit
        ; Story 16.14: the instance clears 64 whenever 128 is set, so the pair is refused rather than
        ; stored as something other than what was sent.
        Set tFlagsType = pArgs.%GetTypeOf(..#FIELDFLAGS)
        If (tFlagsType '= "unassigned") && ..WholeIn(pArgs.%Get(..#FIELDFLAGS), 0, ..#FLAGSMAX) {
            Set tFlags = +pArgs.%Get(..#FIELDFLAGS)
            If $ZBoolean(tFlags, ..#FLAGENABLED, 1) && $ZBoolean(tFlags, ..#FLAGKERBEROSONLY, 1) Do ..Add(.pViolations, ..#FIELDFLAGS, ##class(OcuPilot.Api.LdapError).#FLAGSKERBEROS)
        }
        ; An LDAP configuration needs a host (the vendor's #1482); judged when the hosts or the flags
        ; move, over the effective value of each.
        Set tHostsType = pArgs.%GetTypeOf(..#FIELDHOSTS)
        If ((tHostsType = "array") || (tHostsType = "unassigned")) && ((tHostsType '= "unassigned") || (tFlagsType '= "unassigned")) {
            If '..KerberosOnly(..Effective(pArgs, pFresh, ..#FIELDFLAGS)) && (..HostCount(pArgs, pFresh) = 0) Do ..Add(.pViolations, ..#FIELDHOSTS, ##class(OcuPilot.Api.LdapError).#HOSTREQUIRED)
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

/// <p>The value of <var>pField</var> that <var>pArgs</var> carries, or else <var>pFresh</var>'s, or
/// <code>""</code>.</p>
ClassMethod Effective(pArgs As %DynamicObject, pFresh As %DynamicObject, pField As %String)
{
    If $IsObject(pArgs) && (pArgs.%GetTypeOf(pField) '= "unassigned") Quit pArgs.%Get(pField)
    If $IsObject(pFresh) && (pFresh.%GetTypeOf(pField) '= "unassigned") Quit pFresh.%Get(pField)
    Quit ""
}

/// <p>Whether the flags <var>pFlags</var> mark a Kerberos-only configuration (bit 128).</p>
ClassMethod KerberosOnly(pFlags) As %Boolean
{
    If $IsObject(pFlags) || '$IsValidNum(pFlags) Quit 0
    Quit ''$ZBoolean(+pFlags, ..#FLAGKERBEROSONLY, 1)
}

/// <p>How many non-empty host names the effective <code>LDAPHostNames</code> holds: <var>pArgs</var>'s
/// array when it carries one, or else <var>pFresh</var>'s.</p>
ClassMethod HostCount(pArgs As %DynamicObject, pFresh As %DynamicObject) As %Integer
{
    Set tHosts = ..Effective(pArgs, pFresh, ..#FIELDHOSTS)
    If '$IsObject(tHosts) || 'tHosts.%IsA("%Library.DynamicArray") Quit 0
    Set tCount = 0
    Set tIterator = tHosts.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tHost) {
        If '$IsObject(tHost) && ($ZStrip(tHost, "<>W") '= "") Set tCount = tCount + 1
    }
    Quit tCount
}

/// <p><var>pArgs</var> with the classic page's Kerberos-only values filled in, as a new
/// <class>%DynamicObject</class>: when the effective flags (<var>pArgs</var>'s, or else
/// <var>pFresh</var>'s) mark a Kerberos-only configuration, an empty effective host list is sent as
/// <parameter>UNKNOWNHOST</parameter> and an empty effective search user as
/// <parameter>UNKNOWNUSER</parameter>. Any other value is copied unchanged. Both callers apply it
/// before the rules and in the tool's merge, so the reviewed diff carries what is sent.</p>
ClassMethod KerberosFilled(pArgs As %DynamicObject, pFresh As %DynamicObject) As %DynamicObject
{
    Set tOut = {}
    If $IsObject(pArgs) Set tOut = ##class(%DynamicAbstractObject).%FromJSON(pArgs.%ToJSON())
    If '..KerberosOnly(..Effective(tOut, pFresh, ..#FIELDFLAGS)) Quit tOut
    Set tHostsType = tOut.%GetTypeOf(..#FIELDHOSTS)
    If ((tHostsType = "array") || (tHostsType = "unassigned")) && (..HostCount(tOut, pFresh) = 0) {
        Set tHosts = []
        Do tHosts.%Push(..#UNKNOWNHOST, "string")
        Do tOut.%Set(..#FIELDHOSTS, tHosts)
    }
    Set tUser = ..Effective(tOut, pFresh, ..#FIELDUSER)
    If '$IsObject(tUser) && ($ZStrip(tUser, "<>W") = "") Do tOut.%Set(..#FIELDUSER, ..#UNKNOWNUSER, "string")
    Quit tOut
}

/// <p>A new configuration's values for the twenty-nine settable fields
/// (<method>OcuPilot.Kernel.Proposal.Prohibited.LdapFields</method>), shaped as the vendor's own
/// <code>GET</code> answers them: a new <class>Security.LDAPConfigs</class> object's initial values,
/// read in <code>%SYS</code> (AD-16), with <code>LDAPFlags</code>' Kerberos-only bit cleared so the
/// default is an LDAP configuration that <method>Validate</method> accepts.</p>
ClassMethod Defaults() As %DynamicObject
{
    Set tDefaults = {}
    Set tFields = ##class(OcuPilot.Kernel.Proposal.Prohibited).LdapFields()
    Set tNumbers = $ListFromString(..#NUMBERFIELDS)
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tConfig = $ClassMethod(..#CONFIGCLASS, "%New")
        For tI = 1:1:$ListLength(tFields) {
            Set tField = $List(tFields, tI)
            If tField = "LDAPAttributes" {
                Set tList = []
                Set tHeld = tConfig.LDAPAttributes
                For tJ = 1:1:tHeld.Count() {
                    If tHeld.GetAt(tJ) '= "" Do tList.%Push(tHeld.GetAt(tJ), "string")
                }
                Set tHeld = ""
                Do tDefaults.%Set(tField, tList)
                Continue
            }
            If tField = ..#FIELDHOSTS {
                Set tList = []
                Set tText = tConfig.LDAPHostNames
                For tJ = 1:1:$Length(tText, " ") {
                    If $Piece(tText, " ", tJ) '= "" Do tList.%Push($Piece(tText, " ", tJ), "string")
                }
                Do tDefaults.%Set(tField, tList)
                Continue
            }
            Set tValue = $Property(tConfig, tField)
            If tField = ..#FIELDFLAGS Set tValue = $ZBoolean(+tValue, ..#FLAGKERBEROSONLY, 2)
            If $ListFind(tNumbers, tField) {
                Do tDefaults.%Set(tField, +tValue, "number")
            } Else {
                Do tDefaults.%Set(tField, tValue, "string")
            }
        }
        Set tConfig = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tDefaults = {}
    }
    Quit tDefaults
}

/// <p>The complete body a create sends (AD-4's "complete set": the vendor refuses a partial body on
/// an absent name, #1482, measured): <method>Defaults</method>, then every settable field
/// <var>pArgs</var> carries, with the Kerberos-only values filled in
/// (<method>KerberosFilled</method>), in <method>OcuPilot.Kernel.Proposal.Mint.Compose</method>'s
/// contract. <var>pDiff</var> is one <code>{field, before: "", after}</code> per supplied or filled
/// field (AD-54); <var>pUnchanged</var> is the payload properties no row names. Both callers of
/// <class>OcuPilot.Screen.Tool.LdapCreate</class> compose through this.</p>
ClassMethod Compose(pArgs As %DynamicObject, Output pPayload As %DynamicObject, Output pDiff As %DynamicArray, Output pUnchanged As %Integer, Output pProblem As %String) As %Status
{
    Set pPayload = ""
    Set pDiff = []
    Set pUnchanged = 0
    Set pProblem = ""
    Set tSC = $$$OK
    Try {
        Set tPayload = ..Defaults()
        Set tArgs = ..KerberosFilled(pArgs, tPayload)
        Set tFields = ##class(OcuPilot.Kernel.Proposal.Prohibited).LdapFields()
        Set tTotal = 0
        For tI = 1:1:$ListLength(tFields) {
            Set tField = $List(tFields, tI)
            If tPayload.%GetTypeOf(tField) '= "unassigned" Set tTotal = tTotal + 1
            Set tType = tArgs.%GetTypeOf(tField)
            If tType = "unassigned" Continue
            If (tType = "array") || (tType = "object") {
                Do tPayload.%Set(tField, ##class(%DynamicAbstractObject).%FromJSON(tArgs.%Get(tField).%ToJSON()))
            } Else {
                Do tPayload.%Set(tField, tArgs.%Get(tField), tType)
            }
            Set tRow = {}
            Do tRow.%Set("field", tField, "string")
            Do tRow.%Set("before", "", "string")
            Do tRow.%Set("after", ##class(OcuPilot.Kernel.Proposal.Mint).Display(tArgs.%Get(tField), tType), "string")
            Do pDiff.%Push(tRow)
        }
        Set pPayload = tPayload
        Set pUnchanged = tTotal - pDiff.%Size()
    } Catch ex {
        Set pPayload = ""
        Set pDiff = []
        Set pUnchanged = 0
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The name the instance stores for <var>pName</var>, in <var>pCanonical</var>, and the base DN it
/// derives from it, in <var>pBaseDN</var>: <code>Security.LDAPConfigs.FormatName</code>, read in
/// <code>%SYS</code> (AD-16). An error status is the vendor's refusal of the name's shape (#906).</p>
ClassMethod Canonical(pName As %String, Output pCanonical As %String, Output pBaseDN As %String) As %Status
{
    Set (pCanonical, pBaseDN) = ""
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tSC = $ClassMethod(..#CONFIGCLASS, "FormatName", pName, .tNew, .tBase)
        Set $NAMESPACE = tOrigNS
        If $$$ISOK(tSC) {
            Set pCanonical = $Get(tNew)
            Set pBaseDN = $Get(tBase)
        }
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Add <var>pName</var>'s violation, on <parameter>FIELDNAME</parameter>, or none: an empty name
/// is <parameter>OcuPilot.Api.Error.LDAPFIELDREQUIRED</parameter>, and a name
/// <method>Canonical</method> refuses or would store differently other than by case is
/// <parameter>OcuPilot.Api.LdapError.NAMEFORM</parameter> (AD-13): the instance stores only the
/// canonical form, and its <code>Exists</code> also finds a configuration by its short name, so a
/// non-canonical name would key a different spelling of a stored one.</p>
ClassMethod NameViolation(pName As %String, ByRef pViolations) As %Status
{
    If pName = "" {
        Do ..Add(.pViolations, ..#FIELDNAME, ##class(OcuPilot.Api.Error).#LDAPFIELDREQUIRED)
        Quit $$$OK
    }
    Set tSC = ..Canonical(pName, .tCanonical, .tBaseDN)
    If $$$ISERR(tSC) || ($ZConvert(tCanonical, "L") '= $ZConvert(pName, "L")) Do ..Add(.pViolations, ..#FIELDNAME, ##class(OcuPilot.Api.LdapError).#NAMEFORM)
    Quit $$$OK
}

/// <p>Whether a configuration named <var>pName</var> exists, in <var>pTaken</var>, read through the
/// create tool's own port, endpoint and read type (AD-52). An error status means the question was not
/// answered; only a 404 is "free".</p>
ClassMethod Taken(pName As %String, Output pTaken As %Boolean) As %Status
{
    Set pTaken = 0
    Set tSC = $$$OK
    Try {
        Set tClass = ..#CREATETOOL
        Kill tQuery
        Set tQuery($ClassMethod(tClass, "IdParam")) = pName
        Set tReadSC = $ClassMethod($ClassMethod(tClass, "PortClass"), "Invoke", $ClassMethod(tClass, "Endpoint"), $ClassMethod(tClass, "ReadType"), .tQuery, "", .tFresh, .tHttp, .tFault)
        If $$$ISERR(tReadSC) {
            If +$Get(tHttp) '= 404 Set tSC = tReadSC
            Quit
        }
        Set pTaken = ($IsObject($Get(tFresh)) && tFresh.%IsA("%Library.DynamicObject"))
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Whether the instance's Kerberos authentication is on, in <var>pOn</var>:
/// <class>Security.System</class>'s <code>AutheEnabled</code> bit <parameter>AUTHEKERBEROS</parameter>,
/// read in <code>%SYS</code> (AD-16), as the classic page reads it.</p>
ClassMethod KerberosEnabled(Output pOn As %Boolean) As %Status
{
    Set pOn = 0
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tSystem = ##class(Security.System).%OpenId("SYSTEM")
        If $IsObject(tSystem) Set pOn = ''$ZBoolean(+tSystem.AutheEnabled, ..#AUTHEKERBEROS, 1)
        Set tSystem = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
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

/// <p>Answer <code>GET /ldap/form?name=&lt;n&gt;</code>: <code>{ldap, kerberos}</code>, the change
/// tool's fresh read with its <code>Name</code>, and whether the instance's Kerberos authentication
/// is on (<method>KerberosEnabled</method>). The vendor's read carries no search password. A name
/// this instance does not hold, or none, is 404 <parameter>OcuPilot.Api.Error.LDAPABSENT</parameter>;
/// a name it would store differently is 422 <parameter>OcuPilot.Api.LdapError.NAMEFORM</parameter>.</p>
/// <p><code>GET /ldap/form?new=1</code> answers <code>{ldap, kerberos}</code> with a new
/// configuration's values (<method>Defaults</method>) and an empty <code>Name</code>.</p>
ClassMethod HandleForm() As %Status
{
    Set tSC = $$$OK
    Try {
        Set tGateSC = ..Gate(.tRefused)
        If tRefused || $$$ISERR(tGateSC) {
            Set tSC = tGateSC
            Quit
        }
        Set tKerberosSC = ..KerberosEnabled(.tKerberos)
        If $$$ISERR(tKerberosSC) {
            Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tKerberosSC))
            Quit
        }
        If $Get(%request.Data("new", 1)) = "1" {
            Set tLdap = {}
            Do tLdap.%Set(..#FIELDNAME, "", "string")
            Set tFresh = ..Defaults()
        } Else {
            Set tName = $Get(%request.Data("name", 1))
            Kill tViolations
            Set tViolations = 0
            If tName '= "" Do ..NameViolation(tName, .tViolations)
            If tViolations > 0 {
                Set tSC = ..RenderViolations(.tViolations)
                Quit
            }
            Set tReadSC = ..Present(tName, .tFresh, .tHttp, .tFault)
            If $$$ISERR(tReadSC) {
                Set tSC = ..RenderRead(tReadSC, tHttp, tFault)
                Quit
            }
            Set tLdap = {}
            Do tLdap.%Set(..#FIELDNAME, tName, "string")
        }
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
        Do tBody.%Set("kerberos", tKerberos, "boolean")
        Set tSC = ##class(OcuPilot.Api.Response).JSON(tBody)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>Answer <code>GET /ldap/name?name=&lt;n&gt;</code>: <code>{name, canonical, baseDN, taken}</code>,
/// the name the instance would store for <var>n</var> and the base DN it derives
/// (<method>Canonical</method>), and whether a configuration already holds that name. An empty name
/// is 422 <parameter>OcuPilot.Api.Error.LDAPFIELDREQUIRED</parameter> and one the vendor refuses 422
/// <parameter>OcuPilot.Api.LdapError.NAMEFORM</parameter>, each on <code>Name</code>. A look-up that
/// cannot be made is a refusal envelope, never an assertion that the name is free.</p>
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
        Kill tViolations
        Set tViolations = 0
        If tName = "" Do ..Add(.tViolations, ..#FIELDNAME, ##class(OcuPilot.Api.Error).#LDAPFIELDREQUIRED)
        If tViolations = 0 {
            Set tCanonicalSC = ..Canonical(tName, .tCanonical, .tBaseDN)
            If $$$ISERR(tCanonicalSC) || (tCanonical = "") Do ..Add(.tViolations, ..#FIELDNAME, ##class(OcuPilot.Api.LdapError).#NAMEFORM)
        }
        If tViolations > 0 {
            Set tSC = ..RenderViolations(.tViolations)
            Quit
        }
        Set tTakenSC = ..Taken(tCanonical, .tTaken)
        If $$$ISERR(tTakenSC) {
            Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tTakenSC))
            Quit
        }
        Set tBody = {}
        Do tBody.%Set("name", tName, "string")
        Do tBody.%Set("canonical", tCanonical, "string")
        Do tBody.%Set("baseDN", tBaseDN, "string")
        Do tBody.%Set("taken", tTaken, "boolean")
        Set tSC = ##class(OcuPilot.Api.Response).JSON(tBody)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>Answer <code>GET /ldap/examples</code>: <code>{universal, group, instance}</code>, the text
/// <code>Security.LDAPConfigs.FormatExample</code> answers in modes 1, 2 and 3 for the group inputs
/// the query carries (<parameter>EXAMPLEINPUTS</parameter>; <code>UniversalGroup</code> is
/// <code>1</code> or <code>0</code>), read in <code>%SYS</code> (AD-16). The text is the instance's
/// own, lines separated by CR LF; it is answered to this request alone.</p>
ClassMethod HandleExamples() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set tGateSC = ..Gate(.tRefused)
        If tRefused || $$$ISERR(tGateSC) {
            Set tSC = tGateSC
            Quit
        }
        For tI = 1:1:$Length(..#EXAMPLEINPUTS, ",") {
            Set tInput($Piece(..#EXAMPLEINPUTS, ",", tI)) = $Get(%request.Data($Piece(..#EXAMPLEINPUTS, ",", tI), 1))
        }
        Set tUniversal = (tInput("UniversalGroup") = "1") || ($ZConvert(tInput("UniversalGroup"), "L") = "true")
        Set tBody = {}
        Set tExampleSC = $$$OK
        Set $NAMESPACE = "%SYS"
        For tMode = 1, 2, 3 {
            Kill tText
            Set tExampleSC = $ClassMethod(..#CONFIGCLASS, "FormatExample", tMode, tInput("OrganizationId"), tInput("GroupId"), tInput("InstanceId"), tInput("RoleId"), tInput("EscalationRoleId"), tInput("NamespaceId"), tInput("RoutineId"), tInput("DelimiterId"), tUniversal, tInput("LDAPGroupId"), tInput("LDAPInstanceId"), .tText)
            If $$$ISERR(tExampleSC) Quit
            Do tBody.%Set($Case(tMode, 1: "universal", 2: "group", : "instance"), $Get(tText), "string")
        }
        Set $NAMESPACE = tOrigNS
        If $$$ISERR(tExampleSC) {
            Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tExampleSC))
            Quit
        }
        Set tSC = ##class(OcuPilot.Api.Response).JSON(tBody)
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>Answer <code>POST /ldap/:id/test</code>: test authentication of the body's
/// <code>{Username, Password}</code> against the saved configuration <var>pId</var> -- one path
/// segment, decoded once here (AD-13) -- and answer <code>{lines}</code> with 200, the instance's own
/// console lines (<method>Test</method>).</p>
/// <p><b>Screen-only</b> (AD-39's fourth named exception): no tool issues it, and neither the
/// password nor the lines are written anywhere -- no log line, ledger row, audit payload, screen
/// context or tool result. The gate is the form's pairs and the custom resource of the classic test
/// page (<parameter>TESTPAGE</parameter>, AD-44). An empty user name or password, or a user name
/// carrying <code>@</code>, is one 422 envelope; a configuration the instance does not hold is 404
/// <parameter>OcuPilot.Api.Error.LDAPABSENT</parameter>.</p>
ClassMethod HandleTest(pId As %String) As %Status
{
    Set tSC = $$$OK
    Set tBody = ""
    Try {
        Set tGateSC = ..Gate(.tRefused, ..#TESTPAGE)
        If tRefused || $$$ISERR(tGateSC) {
            Set tSC = tGateSC
            Quit
        }
        Set tReadSC = ##class(OcuPilot.Kernel.Utils).ReadRequestBody(.tBody, .tStage)
        If $$$ISERR(tReadSC) || '$IsObject(tBody) || 'tBody.%IsA("%Library.DynamicObject") {
            Set tBody = ""
            Set tSC = ##class(OcuPilot.Api.Error).Render(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#REASONAGENTBADBODY, ##class(OcuPilot.Api.Error).#AGENTBADBODY)
            Quit
        }
        Set tName = ##class(OcuPilot.Kernel.EntityId).Decode(pId)
        Set tTestSC = ..Test(tName, tBody, .tResult, .tHttp, .tFault, .tViolations)
        Set tBody = ""
        If $Get(tViolations) > 0 {
            Set tSC = ..RenderViolations(.tViolations)
            Quit
        }
        If $$$ISERR(tTestSC) {
            Set tSC = ..RenderRead(tTestSC, $Get(tHttp), $Get(tFault))
            Quit
        }
        Set tSC = ##class(OcuPilot.Api.Response).JSON(tResult)
    } Catch ex {
        Set tBody = ""
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>Test authentication of <var>pBody</var>'s <code>Username</code> and <code>Password</code>
/// against configuration <var>pName</var>, answering <code>{lines}</code> in <var>pResult</var>. The
/// vendor's test picks its configuration by the domain after <code>@</code>, so the user name is sent
/// as <code>&lt;user&gt;@&lt;name&gt;</code>; it runs in process through the change tool's own port
/// (<parameter>OcuPilot.Port.AdminPort.CONNECTIONTESTTYPES</parameter>), never queued (AD-26).</p>
/// <p><b>Caller contract:</b> <var>pViolations</var> is the violation array; a non-zero count means
/// nothing was tested. Otherwise an error status carries <var>pHttpStatus</var> and
/// <var>pFault</var>, 404 for a configuration the instance does not hold. The password exists as this
/// frame's local alone and is cleared before it returns (AD-35).</p>
ClassMethod Test(pName As %String, pBody As %DynamicObject, Output pResult As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, Output pViolations) As %Status
{
    Set pResult = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Kill pViolations
    Set pViolations = 0
    Set tSC = $$$OK
    Set (tUser, tPassword, tRequest) = ""
    Try {
        Do ..NameViolation(pName, .pViolations)
        If pViolations > 0 Quit
        If pBody.%GetTypeOf(..#TESTUSER) = "string" Set tUser = pBody.%Get(..#TESTUSER)
        If pBody.%GetTypeOf(..#TESTPASSWORD) = "string" Set tPassword = pBody.%Get(..#TESTPASSWORD)
        If $ZStrip(tUser, "<>W") = "" {
            Do ..Add(.pViolations, ..#TESTUSER, ##class(OcuPilot.Api.LdapError).#TESTREQUIRED)
        } ElseIf tUser [ "@" {
            Do ..Add(.pViolations, ..#TESTUSER, ##class(OcuPilot.Api.LdapError).#TESTUSERNAME)
        }
        If tPassword = "" Do ..Add(.pViolations, ..#TESTPASSWORD, ##class(OcuPilot.Api.LdapError).#TESTREQUIRED)
        If pViolations > 0 Quit
        Set tSC = ..Present(pName, .tFresh, .pHttpStatus, .pFault)
        Set tFresh = ""
        If $$$ISERR(tSC) Quit
        Kill tQuery
        Set tRequest = {}
        Do tRequest.%Set(..#TESTUSER, tUser _ "@" _ pName, "string")
        Do tRequest.%Set(..#TESTPASSWORD, tPassword, "string")
        Set tPassword = ""
        Set tSC = $ClassMethod($ClassMethod(..#UPDATETOOL, "PortClass"), "Invoke", $ClassMethod(..#UPDATETOOL, "Endpoint"), "TEST", .tQuery, tRequest, .pResult, .pHttpStatus, .pFault)
        Set tRequest = ""
    } Catch ex {
        Set pResult = ""
        Set tSC = ex.AsStatus()
    }
    Set (tPassword, tRequest) = ""
    Quit tSC
}

/// <p>Render <var>pViolations</var> as one 422 <parameter>OcuPilot.Api.Error.LDAPVALIDATION</parameter>
/// envelope carrying every broken rule in <code>detail.violations</code>, each a
/// <code>{field, code, reason}</code> object (AD-39).</p>
ClassMethod RenderViolations(ByRef pViolations) As %Status
{
    Set tDetail = {}
    Do tDetail.%Set("violations", ##class(OcuPilot.Kernel.AgentRules).ViolationsJson(.pViolations))
    Quit ##class(OcuPilot.Api.Error).Render(422, ##class(OcuPilot.Api.Error).#VALIDATIONFAILED, ##class(OcuPilot.Api.Error).#REASONLDAPVALIDATION, ##class(OcuPilot.Api.Error).#LDAPVALIDATION, tDetail)
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

/// <p>Refuse a caller who does not hold the form's declared pairs (AD-8), or the custom resource
/// assigned to a classic page <var>pPages</var> names (comma-separated, AD-44):
/// <var>pRefused</var> 1 means the envelope is written and the caller writes nothing else.</p>
ClassMethod Gate(Output pRefused As %Boolean, pPages As %String = "") As %Status
{
    Set pRefused = 0
    Set tFailedPair = ""
    If '##class(OcuPilot.Screen.Gate).Evaluate(..#DESCRIPTORCLASS, .tFailedPair) {
        Set pRefused = 1
        Quit ##class(OcuPilot.Kernel.Denial).Envelope(tFailedPair)
    }
    If pPages = "" Quit $$$OK
    If ##class(OcuPilot.Screen.Gate).EvaluatePairs(##class(OcuPilot.Screen.Gate).WithClassicPages("", pPages), .tFailedPair) Quit $$$OK
    Set pRefused = 1
    Quit ##class(OcuPilot.Kernel.Denial).Envelope(tFailedPair)
}

/// <p>Append one <code>(field, code)</code> violation.</p>
ClassMethod Add(Output pViolations, pField As %String, pCode As %String) [ Private ]
{
    Set pViolations($Increment(pViolations)) = $ListBuild(pField, pCode)
}

}

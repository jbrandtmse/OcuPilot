/// <p>The service editor's rules (AD-39, AD-55): the one rule set <class>OcuPilot.Screen.Tool.ServiceUpdate</class>'s
/// mint and <class>OcuPilot.Area.Permissions.ServiceSave</class>'s Save apply (<method>Validate</method>),
/// the one reading of an allowed-connection entry (<method>EntryParts</method>,
/// <method>Canonical</method>), and the form's read (<method>HandleForm</method>).</p>
/// <p><b>Every sentence is <method>OcuPilot.Api.Error.ReasonForViolation</method>'s.</b> Each rule
/// refuses a value the vendor would accept and misread (measured on this build): an entry holding a
/// semicolon is split into two, a role the instance does not hold is stored as named, an
/// authentication method outside the service's own capabilities is masked away with a 200, and an
/// address <code>Modify</code> cannot use -- one <code>ValidateClientSystemsIP</code> refuses, one on a
/// service that checks no address, or roles on one that gives none -- is stored as sent.</p>
Class OcuPilot.Area.Permissions.ServiceRules Extends %RegisteredObject
{

/// <p>The tool both callers resolve the write through (AD-55).</p>
Parameter UPDATETOOL = "OcuPilot.Screen.Tool.ServiceUpdate";

/// <p>The screen whose declared pairs gate the routes (AD-8).</p>
Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.ServiceForm";

Parameter FIELDAUTHE = "AutheEnabled";

Parameter FIELDCLIENTSYSTEMS = "ClientSystems";

Parameter FIELDENABLED = "Enabled";

/// <p>The <code>Capabilities</code> bits a service's allowed methods, allowed addresses and
/// per-address roles hang on (<file>irissys/%sySecurity.inc</file>'s
/// <code>$$$EnablePrivilegeBasedSecurity</code>, <code>$$$EnableClientSystemSecurity</code> and
/// <code>$$$EnableClientSystemSecurityRoles</code>), which the classic Edit Service dialog draws
/// its three groups by.</p>
Parameter CAPABILITYMETHODS As INTEGER = 4;

Parameter CAPABILITYADDRESSES As INTEGER = 8;

Parameter CAPABILITYROLES As INTEGER = 16;

/// <p>The message domain the instance holds the authentication-method labels in, read with
/// <code>$$FormatMessage^%occMessages</code>; the classic dialog's <code>$$$Authe&lt;X&gt;Str</code>
/// macros expand to it.</p>
Parameter SERVICESDOMAIN = "%SECURITY.Services";

/// <p>Every authentication bit the classic dialog can offer, as <code>&lt;bit&gt;:&lt;messageKey&gt;</code>
/// pairs in the order its <code>AuthList</code> draws them (<class>%CSP.UI.Portal.Dialog.Service</class>).
/// A service offers a bit only where both its <code>AutheEnabledCapabilities</code> and the instance's
/// <property>Security.System.AutheEnabled</property> carry it.</p>
Parameter AUTHEMETHODS = "64:AutheUnauthenticatedStr,16:AutheOSStr,131072:AutheOSLDAPStr,32:AutheCacheStr,128:AutheKBStr,4:AutheK5APIStr,2:AutheK5PromptStr,1:AutheK5CCacheStr,512:AutheKBIntegrityStr,256:AutheKBEncryptionStr,8:AutheK5KeyTabStr,8192:AutheDelegatedStr,2048:AutheLDAPStr,2097152:AutheTwoFactorPWStr,1048576:AutheTwoFactorSMSStr,33554432:AutheMutualTLSStr,67108864:AutheOAuth2Str";

/// <p>The role list the form's role options come from, read through the change tool's own port
/// (AD-52).</p>
Parameter ROLEENDPOINT = "Security.Role";

Parameter ROLELISTTYPE = "LIST";

/// <p>The address a role option is judged on: the kernel's service verdict asks about a role given
/// to an address, and any one address answers it (<method>RoleOptions</method>).</p>
Parameter PROBEADDRESS = "0.0.0.0";

/// <p>Every rule a service change applies to the fields <var>pArgs</var> carries, read against the
/// service <var>pName</var> whose fresh read is <var>pFresh</var>, in <var>pViolations</var> as
/// <code>pViolations(n) = $ListBuild(field, code)</code> with the count in
/// <code>pViolations</code>.</p>
/// <p><code>Enabled</code> is a boolean; <code>ClientSystems</code> an array of entries, each
/// <code>address</code> or <code>address|role,role</code> (or the vendor's own
/// <code>address:role,role</code>) with no whitespace or semicolon
/// (<parameter>OcuPilot.Api.Error.SERVICEADDRESSSHAPE</parameter>) and every role one
/// <class>Security.Roles</class> holds (<parameter>OcuPilot.Api.Error.SERVICEADDRESSROLE</parameter>);
/// <code>AutheEnabled</code> a whole number whose every bit the service's own
/// <code>AutheEnabledCapabilities</code> carries
/// (<parameter>OcuPilot.Api.Error.SERVICEAUTHEUNSUPPORTED</parameter>), read in <code>%SYS</code>
/// (AD-16) and skipped for a service the instance does not hold.</p>
/// <p>An entry that is not exactly one of <var>pFresh</var>'s -- one this change adds or rewrites --
/// is also judged by <method>AddedViolations</method>: its address by the vendor's own check, and
/// the service's <code>Capabilities</code> for an address and for roles. An entry the instance
/// already holds is judged by the shape and role rules alone, never by those three.</p>
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
            Set tSC = ..AddedViolations(pName, pArgs.%Get(..#FIELDCLIENTSYSTEMS), pFresh, .pViolations)
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
        Do ..EntryParts(tEntry, .tAddress, .tList)
        For tI = 1:1:$ListLength(tList) {
            Set tRole = $List(tList, tI)
            Set tRoles($ZConvert(tRole, "U")) = tRole
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

/// <p>Add the three rules an added or changed entry answers to: each entry of <var>pEntries</var> that
/// is shaped (<method>EntryShaped</method>) and is not exactly an entry of <var>pFresh</var>'s
/// <code>ClientSystems</code>. At most one of each on <code>ClientSystems</code>:
/// <parameter>OcuPilot.Api.ServiceError.ADDRESSINVALID</parameter> when
/// <code>Security.Services.ValidateClientSystemsIP</code> answers 1, 2 or 3 for its address;
/// <parameter>OcuPilot.Api.ServiceError.ADDRESSUNSUPPORTED</parameter> when the service's
/// <code>Capabilities</code> lacks <parameter>CAPABILITYADDRESSES</parameter>; and
/// <parameter>OcuPilot.Api.ServiceError.ADDRESSROLEUNSUPPORTED</parameter> when the entry carries roles
/// and those lack <parameter>CAPABILITYROLES</parameter>. The two capability rules are not judged for a
/// service <var>pName</var> the instance does not hold.</p>
ClassMethod AddedViolations(pName As %String, pEntries As %DynamicArray, pFresh As %DynamicObject, ByRef pViolations) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set tHeld = ..HeldEntries(pFresh)
    Set tAdded = ""
    Set tIterator = pEntries.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tEntry) {
        If $IsObject(tEntry) || (pEntries.%GetTypeOf(tIndex) '= "string") Continue
        If '..EntryShaped(tEntry) Continue
        If $ListFind(tHeld, tEntry) Continue
        Set tAdded = tAdded _ $ListBuild(tEntry)
    }
    If tAdded = "" Quit tSC
    Set tSC = ..Capabilities(pName, .tAutheCapabilities, .tRead, .tCapabilities)
    If $$$ISERR(tSC) Quit tSC
    Set (tInvalid, tUnsupported, tRoleUnsupported) = 0
    For tI = 1:1:$ListLength(tAdded) {
        Do ..EntryParts($List(tAdded, tI), .tAddress, .tRoles)
        Set tSC = ..AddressValidity(tAddress, .tValidity)
        If $$$ISERR(tSC) Quit
        If (tValidity = 1) || (tValidity = 2) || (tValidity = 3) Set tInvalid = 1
        If tRead && '..HasBit(tCapabilities, ..#CAPABILITYADDRESSES) Set tUnsupported = 1
        If tRead && (tRoles '= "") && '..HasBit(tCapabilities, ..#CAPABILITYROLES) Set tRoleUnsupported = 1
    }
    If $$$ISERR(tSC) Quit tSC
    If tInvalid Do ..Add(.pViolations, ..#FIELDCLIENTSYSTEMS, ##class(OcuPilot.Api.ServiceError).#ADDRESSINVALID)
    If tUnsupported Do ..Add(.pViolations, ..#FIELDCLIENTSYSTEMS, ##class(OcuPilot.Api.ServiceError).#ADDRESSUNSUPPORTED)
    If tRoleUnsupported Do ..Add(.pViolations, ..#FIELDCLIENTSYSTEMS, ##class(OcuPilot.Api.ServiceError).#ADDRESSROLEUNSUPPORTED)
    Quit tSC
}

/// <p>The entries <var>pFresh</var>'s <code>ClientSystems</code> holds, as a <class>%List</class> of
/// strings, or <code>""</code> for no fresh read.</p>
ClassMethod HeldEntries(pFresh As %DynamicObject) As %List
{
    Set tHeld = ""
    If '$IsObject(pFresh) || (pFresh.%GetTypeOf(..#FIELDCLIENTSYSTEMS) '= "array") Quit tHeld
    Set tIterator = pFresh.%Get(..#FIELDCLIENTSYSTEMS).%GetIterator()
    While tIterator.%GetNext(.tIndex, .tEntry) {
        If $IsObject(tEntry) Continue
        Set tHeld = tHeld _ $ListBuild(tEntry)
    }
    Quit tHeld
}

/// <p>What <code>Security.Services.ValidateClientSystemsIP</code> answers for <var>pAddress</var>, as a
/// number in <var>pAnswer</var>: 0 or 4 for an address the classic page accepts, and 1, 2 or 3 for
/// one it refuses (its <code>ValidateIP</code>). Read in <code>%SYS</code> (AD-16).</p>
ClassMethod AddressValidity(pAddress As %String, Output pAnswer As %Integer) As %Status
{
    Set pAnswer = 0
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set pAnswer = +##class(Security.Services).ValidateClientSystemsIP(pAddress)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>An allowed-connection entry's address and roles, as the kernel reads one
/// (<method>OcuPilot.Kernel.Proposal.Prohibited.EntryParts</method>, the classic dialog's reading),
/// so the rules, the form read, <method>Canonical</method> and the kernel's privilege verdict share
/// one reading.</p>
ClassMethod EntryParts(pEntry As %String, Output pAddress As %String, Output pRoles As %List)
{
    Do ##class(OcuPilot.Kernel.Proposal.Prohibited).EntryParts(pEntry, .pAddress, .pRoles)
}

/// <p><var>pEntry</var> in the one spelling a write sends for an entry it adds or changes:
/// <code>address</code>, or <code>address|role,role</code> (<method>EntryParts</method>).</p>
ClassMethod Canonical(pEntry As %String) As %String
{
    Do ..EntryParts(pEntry, .tAddress, .tRoles)
    If tRoles = "" Quit tAddress
    Quit tAddress _ "|" _ $ListToString(tRoles, ",")
}

/// <p>Whether <var>pMask</var> sets the single bit <var>pBit</var>.</p>
ClassMethod HasBit(pMask As %Integer, pBit As %Integer) As %Boolean
{
    Quit ((+pMask \ pBit) # 2)
}

/// <p>Whether <var>pEntry</var> is one allowed connection the vendor stores as one: an address, with
/// at most one <code>|</code> followed by a comma-separated role list, and no whitespace or
/// semicolon anywhere. An empty address in either spelling (<method>EntryParts</method>), an empty
/// role list after a <code>|</code> and an empty role between commas are all refused. A shape refusal is
/// <parameter>OcuPilot.Api.Error.SERVICEADDRESSSHAPE</parameter>'s, which is why this answers no
/// code of its own.</p>
ClassMethod EntryShaped(pEntry As %String) As %Boolean
{
    If pEntry = "" Quit 0
    If pEntry [ ";" Quit 0
    If $Translate(pEntry, " " _ $Char(9, 10, 13, 160)) '= pEntry Quit 0
    If $Length(pEntry, "|") > 2 Quit 0
    If $Piece(pEntry, "|", 1) = "" Quit 0
    Do ..EntryParts(pEntry, .tAddress, .tRoles)
    If tAddress = "" Quit 0
    If pEntry '[ "|" Quit 1
    Set tList = $Piece(pEntry, "|", 2)
    If tList = "" Quit 0
    For tI = 1:1:$Length(tList, ",") {
        If $Piece(tList, ",", tI) = "" Quit
    }
    Quit ($Piece(tList, ",", tI) '= "")
}

/// <p>The service <var>pName</var>'s <code>AutheEnabledCapabilities</code> mask in
/// <var>pCapabilities</var> and its <code>Capabilities</code> mask in
/// <var>pServiceCapabilities</var>, read in <code>%SYS</code> (AD-16); <var>pRead</var> 0 when the
/// service is not held, which leaves the capability rules unjudged.</p>
ClassMethod Capabilities(pName As %String, Output pCapabilities As %Integer, Output pRead As %Boolean, Output pServiceCapabilities As %Integer) As %Status
{
    Set pCapabilities = 0
    Set pServiceCapabilities = 0
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
        Set pServiceCapabilities = +$Get(tProperties("Capabilities"))
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

/// <p>The members of <var>pArgs</var> among the tool's permitted fields
/// (<method>OcuPilot.Screen.Tool.ServiceUpdate.PermittedFields</method>) whose value differs from
/// <var>pFresh</var>'s, compared in the diff's rendered form, as a new
/// <class>%DynamicObject</class>. Every carried one is kept when there is no fresh read.</p>
ClassMethod Changed(pArgs As %DynamicObject, pFresh As %DynamicObject = "") As %DynamicObject
{
    Set tChanged = {}
    If '$IsObject(pArgs) Quit tChanged
    Set tFields = $ClassMethod(..#UPDATETOOL, "PermittedFields")
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

/// <p>Answer <code>GET /services/form?name=&lt;n&gt;</code>: <code>{service, servesOcuPilot,
/// authenticationMethods, clientSystems, clientRoles, connections, roles}</code>, the service being
/// the change tool's fresh read with its <code>Name</code>, <code>servesOcuPilot</code> whether it is
/// the service OcuPilot is served through
/// (<method>OcuPilot.Kernel.Proposal.Prohibited.IsServingService</method>), and the rest
/// <method>FormMembers</method>'s. A name this instance does not hold, or none, is 404
/// <parameter>OcuPilot.Api.Error.SERVICEABSENT</parameter>.</p>
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
        Set tMembersSC = ..FormMembers(tName, tFresh, tBody)
        If $$$ISERR(tMembersSC) {
            Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tMembersSC))
            Quit
        }
        Set tSC = ##class(OcuPilot.Api.Response).JSON(tBody)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>Set on <var>pBody</var> what the editor draws its groups from, for the service <var>pName</var>
/// whose fresh read is <var>pFresh</var>, each read on the instance as the classic Edit Service
/// dialog reads it:</p>
/// <ul>
/// <li><code>authenticationMethods</code>, <code>[{bit, label}]</code>: every bit of
/// <parameter>AUTHEMETHODS</parameter>, in its order, that both the service's
/// <code>AutheEnabledCapabilities</code> and <property>Security.System.AutheEnabled</property> carry,
/// labelled with the instance's own message from <parameter>SERVICESDOMAIN</parameter>; empty when its
/// <code>Capabilities</code> lacks <parameter>CAPABILITYMETHODS</parameter>.</li>
/// <li><code>clientSystems</code> and <code>clientRoles</code>: whether its <code>Capabilities</code>
/// carries <parameter>CAPABILITYADDRESSES</parameter> and <parameter>CAPABILITYROLES</parameter>.</li>
/// <li><code>connections</code>, <code>[{entry, address, roles}]</code>: one per stored entry, split
/// by <method>EntryParts</method>.</li>
/// <li><code>roles</code>, <code>[{name, privileged}]</code>: <method>RoleOptions</method>'s answer
/// where <code>clientRoles</code> is true, and <code>[]</code> otherwise.</li>
/// </ul>
ClassMethod FormMembers(pName As %String, pFresh As %DynamicObject, pBody As %DynamicObject) As %Status
{
    Set tSC = ..Capabilities(pName, .tAutheCapabilities, .tRead, .tCapabilities)
    If $$$ISERR(tSC) Quit tSC
    Set tMethods = []
    If ..HasBit(tCapabilities, ..#CAPABILITYMETHODS) {
        Set tSC = ..Methods(tAutheCapabilities, .tMethods)
        If $$$ISERR(tSC) Quit tSC
    }
    Do pBody.%Set("authenticationMethods", tMethods)
    Set tRoles = ..HasBit(tCapabilities, ..#CAPABILITYROLES)
    Do pBody.%Set("clientSystems", ..HasBit(tCapabilities, ..#CAPABILITYADDRESSES), "boolean")
    Do pBody.%Set("clientRoles", tRoles, "boolean")
    Set tConnections = []
    Set tHeld = ..HeldEntries(pFresh)
    For tI = 1:1:$ListLength(tHeld) {
        Do ..EntryParts($List(tHeld, tI), .tAddress, .tEntryRoles)
        Set tRow = {}
        Do tRow.%Set("entry", $List(tHeld, tI), "string")
        Do tRow.%Set("address", tAddress, "string")
        Set tNames = []
        For tJ = 1:1:$ListLength(tEntryRoles) {
            Do tNames.%Push($List(tEntryRoles, tJ), "string")
        }
        Do tRow.%Set("roles", tNames)
        Do tConnections.%Push(tRow)
    }
    Do pBody.%Set("connections", tConnections)
    Set tOptions = []
    If tRoles {
        Set tSC = ..RoleOptions(.tOptions)
        If $$$ISERR(tSC) Quit tSC
    }
    Do pBody.%Set("roles", tOptions)
    Quit $$$OK
}

/// <p>The methods the service offers, as <code>[{bit, label}]</code> in <var>pMethods</var>: each bit
/// of <parameter>AUTHEMETHODS</parameter>, in its order, that <var>pCapabilities</var> (the service's
/// <code>AutheEnabledCapabilities</code>) and <property>Security.System.AutheEnabled</property> both
/// carry. Read in <code>%SYS</code> (AD-16).</p>
ClassMethod Methods(pCapabilities As %Integer, Output pMethods As %DynamicArray) As %Status
{
    Set pMethods = []
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tEnabled = 0
        Set tSystem = ##class(Security.System).%OpenId("SYSTEM")
        If $IsObject(tSystem) Set tEnabled = +tSystem.AutheEnabled
        Set tSystem = ""
        For tI = 1:1:$Length(..#AUTHEMETHODS, ",") {
            Set tPair = $Piece(..#AUTHEMETHODS, ",", tI)
            Set tBit = +$Piece(tPair, ":", 1)
            If (tBit = 0) || '..HasBit(pCapabilities, tBit) || '..HasBit(tEnabled, tBit) Continue
            Set tRow = {}
            Do tRow.%Set("bit", tBit, "number")
            Do tRow.%Set("label", $$FormatMessage^%occMessages("", ..#SERVICESDOMAIN, $Piece(tPair, ":", 2)), "string")
            Do pMethods.%Push(tRow)
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set pMethods = []
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The roles this instance holds, as <code>[{name, privileged}]</code> in the order the vendor
/// lists them, read through the change tool's own port (AD-52). <code>privileged</code> is the
/// kernel's own verdict on giving that role to an address
/// (<method>OcuPilot.Kernel.Proposal.Prohibited.GrantsPrivilegeByEffect</method> for a
/// <code>service</code>), the one the agent's proposal is marked destructive by, so the editor's
/// consequence line and the card's cannot disagree (AD-10).</p>
ClassMethod RoleOptions(Output pRoles As %DynamicArray) As %Status
{
    Set pRoles = []
    Set tSC = $$$OK
    Try {
        Kill tQuery
        Set tSC = $ClassMethod($ClassMethod(..#UPDATETOOL, "PortClass"), "Invoke", ..#ROLEENDPOINT, ..#ROLELISTTYPE, .tQuery, "", .tList, .tHttp, .tFault)
        If $$$ISERR(tSC) Quit
        If '$IsObject(tList) || 'tList.%IsA("%Library.DynamicArray") Quit
        Set tIterator = tList.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tRow) {
            If '$IsObject(tRow) Continue
            Set tName = tRow.%Get("Name")
            If tName = "" Continue
            Set tPayload = {}
            Do tPayload.%Set(..#FIELDCLIENTSYSTEMS, [(..#PROBEADDRESS _ "|" _ tName)])
            Set tTarget = {}
            Do tTarget.%Set(..#FIELDCLIENTSYSTEMS, [])
            Set tSC = ##class(OcuPilot.Kernel.Proposal.Prohibited).GrantsPrivilegeByEffect(##class(OcuPilot.Kernel.Proposal.Prohibited).#TYPESERVICE, tPayload, tTarget, .tGrants)
            If $$$ISERR(tSC) Quit
            Set tEntry = {}
            Do tEntry.%Set("name", tName, "string")
            Do tEntry.%Set("privileged", ''tGrants, "boolean")
            Do pRoles.%Push(tEntry)
        }
    } Catch ex {
        Set pRoles = []
        Set tSC = ex.AsStatus()
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

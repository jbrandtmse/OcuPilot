/// <p>Pins <class>OcuPilot.Screen.Tool.LdapUpdate</class> as the agent reaches it (AD-3, AD-4, AD-6):
/// what it advertises and declares; the mint's diff rows; the four rules at the mint; a confirmed
/// two-field edit whose every other key reads back as it was; and a configuration deleted between
/// the mint and the confirm refused as changed rather than recreated by the vendor's upsert.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and its protected state readable,
/// and <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>: the two confirm legs create
/// <code>ocup99*</code> LDAP configurations (<class>OcuPilot.Test.ServiceLdapProbe</class>) and write
/// them through the shipped confirm, each removed by exact name. The other legs mint over
/// <class>OcuPilot.Test.ProposalFixture</class>. <method>OnBeforeAllTests</method> refuses anywhere
/// the variable does not read 1.</p>
Class OcuPilot.Test.LdapUpdate Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_SERVICE_CONFIG";

Parameter UPDATE = "OcuPilot.Screen.Tool.LdapUpdate";

Parameter LIST = "OcuPilot.Screen.Descriptor.LdapConfigList";

Parameter SET = "OcuPilot.Kernel.Proposal.Prohibited";

Parameter FIXTUREMINT = "OcuPilot.Test.ProposalMint";

Parameter MINT = "OcuPilot.Kernel.Proposal.Mint";

Parameter CONFIRM = "OcuPilot.Kernel.Proposal.Confirm";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

Parameter PROBE = "OcuPilot.Test.ServiceLdapProbe";

/// <p>A name the instance does not hold, which the fixture legs are about.</p>
Parameter ABSENT = "ocup99absent.invalid";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.LdapUpdate creates and writes LDAP configurations on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was written. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Quit $ClassMethod(..#PROBE, "RemoveAll")
}

Method OnAfterAllTests() As %Status
{
    Quit $ClassMethod(..#PROBE, "RemoveAll")
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining)
    Do $$$AssertStatusOK(tSC, "the probe proposals and turns are removed")
    Do $$$AssertEquals(tRemaining, 0, "and none survives the removal")
    Quit $ClassMethod(..#PROBE, "RemoveAll")
}

/// <p>AD-3, AD-21: the tool admits the template's thirty keys less <code>LDAPCACertFile</code> --
/// the prohibited set's own list -- declares no secret, and is a merge write over the vendor's
/// <code>GET</code> and <code>PUT</code>; the flags and timeouts are typed as the read answers
/// them.</p>
Method TestTheToolDeclaresItsFieldsAndShapes()
{
    Set tSettable = $ClassMethod(..#UPDATE, "SettableFields")
    Do $$$AssertEquals($ListLength(tSettable), 29, "the tool sets twenty-nine fields")
    Do $$$AssertEquals(##class(OcuPilot.Test.ServiceUpdate).Sorted(tSettable), ##class(OcuPilot.Test.ServiceUpdate).Sorted($ClassMethod(..#SET, "PermittedChangeFields", "ldap-configuration")), "which the set permits a change")
    Do $$$AssertEquals($ListFind(tSettable, "LDAPCACertFile") _ " " _ $ListFind(tSettable, "LDAPSearchPassword"), "0 0", "never the certificate file, and no search password")
    Do $$$AssertEquals($ClassMethod(..#UPDATE, "SecretArguments"), "", "it admits no secret")
    Set tSchema = $ClassMethod(..#UPDATE, "InputSchema")
    Do $$$AssertEquals(tSchema.%Get("properties").%Get("LDAPFlags").%Get("type") _ " " _ tSchema.%Get("properties").%Get("LDAPServerTimeout").%Get("type") _ " " _ tSchema.%Get("properties").%Get("LDAPHostNames").%Get("type"), "integer integer array", "typed as the vendor's read answers them")
    Do $$$AssertEquals($ClassMethod(..#UPDATE, "Endpoint") _ " " _ $ClassMethod(..#UPDATE, "ReadType") _ " " _ $ClassMethod(..#UPDATE, "WriteType") _ " " _ $ClassMethod(..#UPDATE, "ChangeAction"), "Security.LDAP GET PUT updated", "a merge write over the vendor's read and PUT")
    Do $$$AssertEquals(##class(OcuPilot.Port.AdminPort).IsMutating("Security.LDAP", "PUT"), 1, "which the port admits")
}

/// <p>AD-4: a mint answers one row per changed field and counts the other twenty-nine sent
/// unchanged.</p>
Method TestTheMintAnswersOneRowPerChange()
{
    Do ##class(OcuPilot.Test.ProposalFixture).Arm(..Fresh())
    Set tSC = ..FixtureMint({"Name": (..#ABSENT), "Description": "changed", "LDAPHostNames": ["h1.invalid", "h2.invalid"]}, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the change is minted: " _ ##class(OcuPilot.Test.ServiceUpdate).Problem(.tFault))
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(tProposal.%Get("changed").%Size() _ " " _ tProposal.%Get("unchangedCount"), "2 28", "two rows, twenty-eight sent unchanged")
}

/// <p>AD-55: the tool's rules refuse at the mint what the form refuses -- flags outside 0 to 255, a
/// host holding a space, an empty required setting and an over-long description -- each by its
/// published sentence.</p>
/// <p>Mutation (Rule 19): drop the <code>Validate</code> call from
/// <method>OcuPilot.Screen.Tool.LdapUpdate.ArgumentProblem</method> -- all four legs go red.</p>
Method TestTheRulesRefuseAtTheMint()
{
    Set tError = "OcuPilot.Api.Error"
    Do ##class(OcuPilot.Test.ProposalFixture).Arm(..Fresh())
    Set tLong = ""
    For tI = 1:1:129 Set tLong = tLong _ "d"
    Set tCases = [{"LDAPFlags": 300}, {"LDAPHostNames": ["a b"]}, {"LDAPBaseDN": ""}, {"Description": (tLong)}]
    Set tCodes = $ListBuild("LDAPFLAGSVALUE", "LDAPHOSTSHAPE", "LDAPFIELDREQUIRED", "LDAPDESCRIPTIONLENGTH")
    For tI = 1:1:$ListLength(tCodes) {
        Set tCase = $ListBuild("", $List(tCodes, tI))
        Set tArgs = tCases.%Get(tI - 1)
        Do tArgs.%Set("Name", ..#ABSENT, "string")
        Set tSC = ..FixtureMint(tArgs, .tProposal, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp, 400, $List(tCase, 2) _ " is refused at the mint")
        Do $$$AssertTrue(##class(OcuPilot.Test.ServiceUpdate).Problem(.tFault) [ ##class(OcuPilot.Api.Error).ReasonForViolation($Parameter(tError, $List(tCase, 2))), $List(tCase, 2) _ ": by its sentence: " _ ##class(OcuPilot.Test.ServiceUpdate).Problem(.tFault))
    }
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteCount(), 0, "and nothing is written")
}

/// <p>AC3, AD-4: a confirmed agent edit of two fields writes through the shipped confirm, and every
/// other key of the vendor's read comes back as it was.</p>
/// <p>Mutation (Rule 19): merge <code>LDAPHostNames</code> by concatenation in the tool's merge --
/// the host leg goes red.</p>
Method TestAConfirmedTwoFieldEditKeepsEveryOtherField()
{
    Set tName = "ocup99ldapconfirm.invalid"
    Set tSC = $ClassMethod(..#PROBE, "CreateLdap", tName)
    Do $$$AssertStatusOK(tSC, "the probe configuration is created")
    If $$$ISERR(tSC) Quit
    Set tSC = $ClassMethod(..#PROBE, "Read", tName, .tBefore, "Security.LDAP")
    Do $$$AssertStatusOK(tSC, "and reads")
    If '$IsObject($Get(tBefore)) Quit
    Set tSC = ..RealMint({"Name": (tName), "Description": "confirmed", "LDAPHostNames": ["h1.invalid", "h2.invalid:636"]}, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the change is minted: " _ ##class(OcuPilot.Test.ServiceUpdate).Problem(.tFault))
    If $$$ISERR(tSC) Quit
    Set tSC = $ClassMethod(..#CONFIRM, "Confirm", tProposal.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertEquals(tHttp, 200, "the confirm writes: " _ $Get(tCode))
    Set tSC = $ClassMethod(..#PROBE, "Read", tName, .tAfter, "Security.LDAP")
    If '$IsObject($Get(tAfter)) Quit
    Do $$$AssertEquals(tAfter.%Get("Description") _ " " _ tAfter.%Get("LDAPHostNames").%ToJSON(), "confirmed [""h1.invalid"",""h2.invalid:636""]", "the two fields change")
    Do $$$AssertEquals(..Others(tBefore, tAfter, $ListBuild("Description", "LDAPHostNames")), "", "and every other key reads back as it was")
}

/// <p>Matrix "Deleted between mint and confirm", AD-4, AD-6: the vendor's <code>PUT</code> creates an
/// absent configuration, so a configuration deleted since the mint is refused as changed at the
/// confirm, and nothing is created.</p>
Method TestADeletedConfigurationIsNotRecreated()
{
    Set tName = "ocup99ldapgone.invalid"
    Set tSC = $ClassMethod(..#PROBE, "CreateLdap", tName)
    Do $$$AssertStatusOK(tSC, "the probe configuration is created")
    If $$$ISERR(tSC) Quit
    Set tSC = ..RealMint({"Name": (tName), "Description": "gone"}, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the change is minted")
    If $$$ISERR(tSC) Quit
    Set tSC = $ClassMethod(..#PROBE, "RemoveLdap", tName)
    Do $$$AssertEquals($ClassMethod(..#PROBE, "LdapExists", tName), 0, "the configuration is deleted")
    Set tSC = $ClassMethod(..#CONFIRM, "Confirm", tProposal.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertEquals(tHttp _ " " _ tCode, "409 " _ ##class(OcuPilot.Kernel.Proposal.Write).#TARGETCHANGED, "the confirm is refused as target changed")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "LdapExists", tName), 0, "and nothing is created")
}

/// <p>AD-10, AD-21: the kernel set, asked about the agent's tool against a live configuration, refuses
/// a change to <code>LDAPCACertFile</code> -- outside the fields it permits -- as an uncovered field and
/// permits a description and host-name change. It writes nothing.</p>
/// <p>Mutation (Rule 19): remove the <code>ldap-configuration</code> branch from
/// <method>OcuPilot.Kernel.Proposal.Prohibited.Prohibits</method> -- this goes red.</p>
Method TestTheKernelSweepsTheReviewedFew()
{
    Set tName = "ocup99ldapkernel.invalid"
    Set tSC = $ClassMethod(..#PROBE, "CreateLdap", tName)
    Do $$$AssertStatusOK(tSC, "the probe configuration is created")
    If $$$ISERR(tSC) Quit
    Set tSC = $ClassMethod(..#PROBE, "Read", tName, .tLive, "Security.LDAP")
    If '$IsObject($Get(tLive)) Quit
    Set tSC = ##class(OcuPilot.Kernel.EntityRef).Key("ldap-configuration", "instance", tName, .tRef)
    Set tTool = $Parameter(..#UPDATE, "TOOLNAME")
    Set tCert = ##class(%DynamicObject).%FromJSON(tLive.%ToJSON())
    Do tCert.%Set("LDAPCACertFile", "/tmp/ocup99.pem", "string")
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Prohibited).Prohibits(tTool, tRef, tCert.%ToJSON(), "[{""field"":""LDAPCACertFile""}]", .tProhibits, .tCode)
    Do $$$AssertStatusOK(tSC, "the set answers")
    Do $$$AssertEquals(tProhibits _ " " _ tCode, "1 " _ $Parameter(..#SET, "UNCOVEREDFIELD"), "the certificate file is refused as a field the set does not cover")
    Set tDescribed = ##class(%DynamicObject).%FromJSON(tLive.%ToJSON())
    Do tDescribed.%Set("Description", "kernel", "string")
    Do tDescribed.%Set("LDAPHostNames", ["h1.invalid", "h2.invalid:636"])
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Prohibited).Prohibits(tTool, tRef, tDescribed.%ToJSON(), "[{""field"":""Description""},{""field"":""LDAPHostNames""}]", .tProhibits, .tCode)
    Do $$$AssertEquals(tProhibits _ " " _ tCode, "0 ", "while a description and host-name change is permitted")
}

/// <p>AD-5, AD-44: the form is built, unlisted, at the list's own route with the editor suffix, over
/// the list's own pairs, and ends with a honoured classic-portal exemption naming the classic page
/// and its same-origin address, while the list declares none; every <code>LDAP.*</code> code
/// carries a sentence.</p>
/// <p>Mutation (Rule 19): set the list's exemption to exempt -- the list leg goes red.</p>
Method TestTheFormDescriptorIsBuiltUnlistedAndExempt()
{
    Set tForm = "OcuPilot.Screen.Descriptor.LdapConfigForm"
    Set tList = ..#LIST
    Do $$$AssertEquals($ClassMethod(tForm, "Route"), $ClassMethod(tList, "Route") _ "/edit", "the form's route is the list's own with the editor suffix")
    Do $$$AssertEquals(''$ClassMethod(tForm, "IsBuilt") _ " " _ (+$ClassMethod(tForm, "SideBarPosition")) _ " " _ $ClassMethod(tForm, "Archetype") _ " " _ $ClassMethod(tForm, "PrimaryEntityType"), "1 0 form-page ldap-configuration", "a built, unlisted form page over the list's type")
    Do $$$AssertEquals($ClassMethod(tForm, "ToolIdentifier"), "security.ldapform", "with its own tool identifier")
    Do $$$AssertEquals($ListToString($ClassMethod(tForm, "PrivilegePairs")), $ListToString($ClassMethod(tList, "PrivilegePairs")), "requiring exactly what the list requires")
    Do $$$AssertEquals($Parameter("OcuPilot.Area.Security.LdapSave", "DESCRIPTORCLASS") _ " " _ $Parameter("OcuPilot.Area.Security.LdapRules", "DESCRIPTORCLASS"), tForm _ " " _ tForm, "and the routes gate on the form's declaration")
    Set tSC = $ClassMethod(tForm, "DeclarationJson", .tDeclaration)
    Do $$$AssertStatusOK(tSC, "the form's declaration parses")
    If $$$ISERR(tSC) Quit
    Set tExemption = tDeclaration.%Get("classicLinkExemption")
    Do $$$AssertEquals(tDeclaration.%Get("classicPage") _ " " _ tExemption.%Get("exempt") _ " " _ tExemption.%Get("label") _ " " _ tExemption.%Get("href"), "%CSP.UI.Portal.LDAP 1 Security LDAP Configs /csp/sys/sec/%25CSP.UI.Portal.LDAPs.zen", "it names its classic page and links out to the classic list")
    Do $$$AssertTrue(tExemption.%Get("reason") [ "Story 16.14", "its reason names the story that removes it")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ClassicLinkProblem(tDeclaration), "", "and the registry honours it")
    Do $$$AssertEquals(tDeclaration.%Get("suggestedPrompts").%Size(), 3, "it declares three suggested prompts")
    Set tSC = $ClassMethod(tList, "DeclarationJson", .tListDeclaration)
    If $$$ISOK(tSC) Do $$$AssertEquals(tListDeclaration.%Get("classicLinkExemption").%Get("exempt"), 0, "while the list declares no exemption")
    Set tCodes = ##class(OcuPilot.Api.Error).LdapViolationCodes()
    For tI = 1:1:$ListLength(tCodes) {
        Do $$$AssertNotEquals(##class(OcuPilot.Api.Error).ReasonForViolation($List(tCodes, tI)), "", $List(tCodes, tI) _ " carries a written sentence")
    }
}

/// <p>The keys of <var>pBefore</var> outside <var>pSkip</var> whose rendered value <var>pAfter</var>
/// does not carry, comma-separated, or <code>""</code>.</p>
ClassMethod Others(pBefore As %DynamicObject, pAfter As %DynamicObject, pSkip As %List) As %String
{
    Set tMoved = ""
    Set tIterator = pBefore.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        If $ListFind(pSkip, tKey) Continue
        Set tWas = ##class(OcuPilot.Kernel.Proposal.Mint).Display(tValue, pBefore.%GetTypeOf(tKey))
        Set tNow = ##class(OcuPilot.Kernel.Proposal.Mint).Display(pAfter.%Get(tKey), pAfter.%GetTypeOf(tKey))
        If tWas '= tNow Set tMoved = tMoved _ $Select(tMoved = "": "", 1: ",") _ tKey
    }
    Quit tMoved
}

/// <p>A configuration as the vendor's read answers one.</p>
ClassMethod Fresh() As %String
{
    Quit {"Description": "", "LDAPAttributes": [], "LDAPAttributeComment": "description", "LDAPAttributeFullName": "displayName", "LDAPAttributeMail": "mail", "LDAPAttributeMobile": "mobile", "LDAPAttributeMobileProvider": "", "LDAPAttributeNameSpace": "intersystems-Namespace", "LDAPAttributeRoutine": "intersystems-Routine", "LDAPAttributeRoles": "intersystems-Roles", "LDAPAttributeEscalationRoles": "intersystems-EscalationRoles", "LDAPBaseDN": "DC=ocup99,DC=invalid", "LDAPBaseDNForGroups": "DC=ocup99,DC=invalid", "LDAPCACertFile": "", "LDAPClientTimeout": 180, "LDAPFlags": 25, "LDAPGroupId": "", "LDAPHostNames": ["ocup99.invalid"], "LDAPInstanceId": "probe_IRIS", "OrganizationId": "intersystems", "GroupId": "Group", "InstanceId": "Instance", "RoleId": "Role", "EscalationRoleId": "EscalationRole", "RoutineId": "Routine", "NamespaceId": "Namespace", "DelimiterId": "-", "LDAPSearchUsername": "CN=ocup99", "LDAPServerTimeout": 60, "LDAPUniqueDNIdentifier": "sAMAccountName"}.%ToJSON()
}

/// <p>Mint one proposal with <var>pArgs</var> through the fixture mint.</p>
Method FixtureMint(pArgs As %DynamicObject, Output pProposal As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Quit ..MintWith(..#FIXTUREMINT, pArgs, .pProposal, .pHttpStatus, .pFault)
}

/// <p>Mint one proposal with <var>pArgs</var> through the shipped mint, which reads the instance.</p>
Method RealMint(pArgs As %DynamicObject, Output pProposal As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Quit ..MintWith(..#MINT, pArgs, .pProposal, .pHttpStatus, .pFault)
}

Method MintWith(pMint As %String, pArgs As %DynamicObject, Output pProposal As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurnKey)
    If $$$ISERR(tSC) Quit tSC
    Set tTool = ..#UPDATE
    Quit $ClassMethod(pMint, "Mint", ..#LIST, $Parameter(tTool, "TOOLNAME"), $Username, "", tTurnKey, pArgs, ..#LIMITS, .pProposal, .pHttpStatus, .pFault, $ClassMethod(tTool, "Endpoint"), $ClassMethod(tTool, "IdParam"), pArgs.%Get("Name"), $ClassMethod(tTool, "IdArgument"), $ClassMethod(tTool, "SettableFields"), tTool)
}

}

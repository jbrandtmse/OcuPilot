/// <p>Pins the LDAP and Kerberos editor's create and delete on both callers (AD-4, AD-6, AD-13,
/// AD-53, AD-54, AD-55): <class>OcuPilot.Screen.Tool.LdapCreate</class>'s mint finds the name absent
/// and composes the complete set, a confirmed create is applied, and a confirm is refused once the
/// name is taken; the create's rules -- the stored name's form, a taken name and a missing host --
/// refuse at the mint and on the Save, and a Kerberos-only create carries the classic page's host and
/// user; the Save's create answers 201 and the configuration reads back; and
/// <class>OcuPilot.Screen.Tool.LdapDelete</class>'s mint, confirm and the list's Delete remove a
/// configuration, a bare name refused and an absent one answering 404; and a stored dotless name
/// asked again at the agent's confirm.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, the test principal
/// holding <code>%All</code>, and <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>: it
/// creates and deletes <code>ocup99*</code> LDAP configurations
/// (<class>OcuPilot.Test.ServiceLdapProbe</class>), each by exact name, and after every test asserts
/// that none remains. <method>OnBeforeAllTests</method> refuses anywhere the variable does not read
/// 1.</p>
Class OcuPilot.Test.LdapCreate Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_SERVICE_CONFIG";

Parameter CREATE = "OcuPilot.Screen.Tool.LdapCreate";

Parameter DELETE = "OcuPilot.Screen.Tool.LdapDelete";

Parameter PROBE = "OcuPilot.Test.ServiceLdapProbe";

Parameter HELPER = "OcuPilot.Test.OAuthServerProbe";

Parameter CONFIRM = "OcuPilot.Kernel.Proposal.Confirm";

/// <p>The create route and the list's screen-action route.</p>
Parameter CREATEPATH = "/ldap";

Parameter ACTIONPATH = "/screens/security.ldap/action";

/// <p>The probe a create makes, and the name in the vendor's short form that it must refuse.</p>
Parameter NEWNAME = "ocup99new.invalid";

Parameter SHORTNAME = "OcuP99New";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.LdapCreate creates and deletes LDAP configurations on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was written. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Quit $ClassMethod(..#PROBE, "RemoveAll")
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Quit $$$OK
}

/// <p>Removes every probe the test made and asserts that no <code>ocup99*</code> configuration
/// remains (AC12).</p>
Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining)
    Set tSC = $ClassMethod(..#PROBE, "RemoveAll")
    Do $$$AssertStatusOK(tSC, "every probe configuration is removed")
    Do $$$AssertEquals(..Residue(), "", "and no ocup99 configuration remains")
    Quit $$$OK
}

Method OnAfterAllTests() As %Status
{
    Quit $ClassMethod(..#PROBE, "RemoveAll")
}

/// <p>AC6, AD-54: the create's mint reads the name and finds it absent, composes the complete set --
/// every supplied field a row, the other settable fields a new configuration's own values, counted
/// unchanged -- and stores a payload carrying all twenty-nine; once the name is taken, the confirm is
/// refused as changed and the taken configuration is not overwritten.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Area.Security.LdapRules.Compose</method> starts from an
/// empty object instead of <method>OcuPilot.Area.Security.LdapRules.Defaults</method> -- the payload
/// leg goes red.</p>
Method TestTheMintComposesTheCompleteSetAndTheConfirmRefusesATakenName()
{
    Set tArgs = ..Args(..#NEWNAME)
    Set tSC = $ClassMethod(..#HELPER, "Mint", ..#CREATE, ..#NEWNAME, tArgs, .tProposal, .tHttp, .tFault, .tTurnKey)
    Do $$$AssertStatusOK(tSC, "the create is minted: " _ $ClassMethod(..#HELPER, "Problem", $Get(tFault)))
    If '$IsObject($Get(tProposal)) Quit
    Do $$$AssertEquals(tProposal.%Get("changed").%Size() _ " " _ tProposal.%Get("unchangedCount"), "5 24", "five rows, twenty-four new-configuration values sent unchanged")
    Set tSC = ##class(OcuPilot.Kernel.State.Propose).GuardedByKey(tProposal.%Get("proposalId"), .tFound, .tValues)
    Set tPayload = ""
    Try { Set tPayload = ##class(%DynamicObject).%FromJSON($Get(tValues("payload"))) } Catch {}
    Do $$$AssertEquals(##class(OcuPilot.Test.ServiceUpdate).Sorted($ListFromString(##class(OcuPilot.Test.OAuthServerProbe).Keys(tPayload))), ##class(OcuPilot.Test.ServiceUpdate).Sorted(##class(OcuPilot.Kernel.Proposal.Prohibited).LdapFields()), "the stored payload is the complete set")
    If $IsObject(tPayload) Do $$$AssertEquals(tPayload.%Get("LDAPUniqueDNIdentifier") _ " " _ tPayload.%Get("LDAPServerTimeout"), ##class(OcuPilot.Area.Security.LdapRules).Defaults().%Get("LDAPUniqueDNIdentifier") _ " " _ ##class(OcuPilot.Area.Security.LdapRules).Defaults().%Get("LDAPServerTimeout"), "its unnamed fields a new configuration's own")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "CreateLdap", ..#NEWNAME), "somebody creates the name since the mint")
    Set tSC = $ClassMethod(..#CONFIRM, "Confirm", tProposal.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertEquals(tHttp _ " " _ $Get(tCode), "409 " _ ##class(OcuPilot.Kernel.Proposal.Write).#TARGETCHANGED, "the confirm is refused as target changed")
    Set tSC = $ClassMethod(..#PROBE, "Read", ..#NEWNAME, .tHeld, "Security.LDAP")
    Do $$$AssertEquals($Select($IsObject($Get(tHeld)): tHeld.%Get("LDAPHostNames").%ToJSON(), 1: ""), "[""ocup99.invalid""]", "and the configuration somebody made is not overwritten")
}

/// <p>AC6, AD-54, AD-58: a create minted for a name the instance does not hold, then confirmed, is
/// applied: the configuration exists, reads back with the hosts sent, and the confirm's read-back
/// matches.</p>
/// <p>Mutation (Rule 19): <parameter>OcuPilot.Screen.Tool.LdapCreate.WRITETYPE</parameter> set to
/// <code>GET</code> -- nothing is created and this goes red.</p>
Method TestAConfirmedAgentCreateIsApplied()
{
    Set tName = "ocup99agentcreate.invalid"
    Set tArgs = ..Args(tName)
    Do tArgs.%Set("LDAPHostNames", ["h1.invalid", "h2.invalid:636"])
    Set tSC = $ClassMethod(..#HELPER, "Mint", ..#CREATE, tName, tArgs, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the create is minted: " _ $ClassMethod(..#HELPER, "Problem", $Get(tFault)))
    If '$IsObject($Get(tProposal)) Quit
    Set tSC = $ClassMethod(..#CONFIRM, "Confirm", tProposal.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertEquals(tHttp, 200, "the confirm writes: " _ $Get(tCode))
    Do $$$AssertEquals($ClassMethod(..#PROBE, "LdapExists", tName), 1, "the configuration exists")
    Set tSC = $ClassMethod(..#PROBE, "Read", tName, .tAfter, "Security.LDAP")
    Do $$$AssertEquals($Select($IsObject($Get(tAfter)): tAfter.%Get("LDAPHostNames").%ToJSON(), 1: ""), "[""h1.invalid"",""h2.invalid:636""]", "with the hosts sent")
    Do $$$AssertEquals($Select($IsObject($Get(tResult)) && (tResult.%GetTypeOf("readBack") = "object"): tResult.%Get("readBack").%Get("verdict"), 1: ""), "matches", "and the confirm's read-back matches")
}

/// <p>AC8, AD-13, AD-55: at the create's mint a bare name is refused by
/// <code>LDAP.NAME.FORM</code>, a name already held by the absence read, and no host on an LDAP
/// configuration by <code>LDAP.HOST.REQUIRED</code>; each by its sentence, and nothing is written. A
/// Kerberos-only create with no host and no search user is minted, its composed payload carrying the
/// classic page's <code>UNKNOWNHOST</code> and <code>UNKNOWNUSER</code>.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Area.Security.LdapRules.Validate</method> skips
/// <code>LDAP.HOST.REQUIRED</code> -- the host leg goes red.</p>
Method TestTheRulesRefuseAtTheMint()
{
    Set tSC = $ClassMethod(..#HELPER, "Mint", ..#CREATE, ..#SHORTNAME, ..Args(..#SHORTNAME), .tProposal, .tHttp, .tFault)
    Do $$$AssertTrue((tHttp = 400) && ($ClassMethod(..#HELPER, "Problem", $Get(tFault)) [ ##class(OcuPilot.Api.LdapError).#REASONNAMEFORM), "a bare name is refused by LDAP.NAME.FORM: " _ $ClassMethod(..#HELPER, "Problem", $Get(tFault)))
    Set tArgs = ..Args(..#NEWNAME)
    Do tArgs.%Set("LDAPHostNames", [])
    Set tSC = $ClassMethod(..#HELPER, "Mint", ..#CREATE, ..#NEWNAME, tArgs, .tProposal, .tHttp, .tFault)
    Do $$$AssertTrue((tHttp = 400) && ($ClassMethod(..#HELPER, "Problem", $Get(tFault)) [ ##class(OcuPilot.Api.LdapError).#REASONHOSTREQUIRED), "no host is refused by LDAP.HOST.REQUIRED: " _ $ClassMethod(..#HELPER, "Problem", $Get(tFault)))
    Do tArgs.%Set("LDAPFlags", 136, "number")
    Do tArgs.%Set("LDAPSearchUsername", "", "string")
    Set tSC = $ClassMethod(..#HELPER, "Mint", ..#CREATE, ..#NEWNAME, tArgs, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "while a Kerberos-only configuration needs no host or search user: " _ $ClassMethod(..#HELPER, "Problem", $Get(tFault)))
    Set tPayload = ""
    If $IsObject($Get(tProposal)) {
        Set tSC = ##class(OcuPilot.Kernel.State.Propose).GuardedByKey(tProposal.%Get("proposalId"), .tFound, .tValues)
        Try { Set tPayload = ##class(%DynamicObject).%FromJSON($Get(tValues("payload"))) } Catch {}
    }
    Do $$$AssertEquals($Select($IsObject(tPayload): tPayload.%Get("LDAPHostNames").%ToJSON() _ " " _ tPayload.%Get("LDAPSearchUsername"), 1: ""), "[""UNKNOWNHOST""] UNKNOWNUSER", "and its composed payload carries the classic page's host and user")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "CreateLdap", ..#NEWNAME), "the name is created")
    Set tSC = $ClassMethod(..#HELPER, "Mint", ..#CREATE, ..#NEWNAME, ..Args(..#NEWNAME), .tProposal, .tHttp, .tFault)
    Do $$$AssertTrue((tHttp = 400) && ($ClassMethod(..#HELPER, "Problem", $Get(tFault)) [ "already present"), "a taken name is refused by the absence read: " _ $ClassMethod(..#HELPER, "Problem", $Get(tFault)))
    Set tSC = $ClassMethod(..#PROBE, "Read", ..#NEWNAME, .tHeld, "Security.LDAP")
    Do $$$AssertEquals($Select($IsObject($Get(tHeld)): tHeld.%Get("LDAPHostNames").%ToJSON(), 1: ""), "[""ocup99.invalid""]", "and the taken configuration keeps its own host")
}

/// <p>AC6, AC8 on the screen's caller: the create Save refuses a bare name, a taken name and no host
/// as one 422 on the field, and a sound create answers 201 naming the stored name, after which the
/// configuration reads back with the sent fields and its read-back matches.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Area.Security.LdapRules.Taken</method> answers false --
/// the taken leg goes red.</p>
Method TestTheSaveCreatesUnderTheStoredName()
{
    For tCase = $ListBuild(..#SHORTNAME, "", "Name LDAP.NAME.FORM"), $ListBuild(..#NEWNAME, "nohost", "LDAPHostNames LDAP.HOST.REQUIRED") {
        Set tArgs = ..Args($List(tCase, 1))
        Do tArgs.%Set("Name", $List(tCase, 1), "string")
        If $List(tCase, 2) = "nohost" Do tArgs.%Set("LDAPHostNames", [])
        Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("POST", ..#CREATEPATH, .tStatus, .tAnswer, tArgs.%ToJSON(), "application/json")
        Do $$$AssertEquals(tStatus _ " " _ ##class(OcuPilot.Test.LdapEdit).FirstViolation($Get(tAnswer)), "422 " _ $List(tCase, 3), $List(tCase, 3) _ " is refused")
    }
    Do $$$AssertEquals($ClassMethod(..#PROBE, "LdapExists", "ocup99new.com") + $ClassMethod(..#PROBE, "LdapExists", ..#NEWNAME), 0, "and nothing is created")
    Set tArgs = ..Args(..#NEWNAME)
    Do tArgs.%Set("Name", ..#NEWNAME, "string")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", $Parameter("OcuPilot.Test.Http", "BASEPATH") _ ..#CREATEPATH, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tStatus, .tText, .tHeaders, tArgs.%ToJSON(), "application/json")
    Set tAnswer = ""
    Try { Set tAnswer = ##class(%DynamicObject).%FromJSON($Get(tText)) } Catch {}
    Do $$$AssertEquals(tStatus, 201, "the create answers 201: " _ $Get(tText))
    Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "application/json", "as application/json")
    If $IsObject($Get(tAnswer)) {
        Do $$$AssertEquals(tAnswer.%Get("name"), ..#NEWNAME, "naming the stored name")
        Do $$$AssertEquals($Select(tAnswer.%GetTypeOf("readBack") = "object": tAnswer.%Get("readBack").%Get("verdict"), 1: ""), "matches", "and its read-back matches")
    }
    Set tSC = $ClassMethod(..#PROBE, "Read", ..#NEWNAME, .tAfter, "Security.LDAP")
    Do $$$AssertEquals($Select($IsObject($Get(tAfter)): tAfter.%Get("LDAPHostNames").%ToJSON() _ " " _ tAfter.%Get("LDAPBaseDN"), 1: ""), "[""h1.invalid""] DC=ocup99new,DC=invalid", "the configuration reads back with the sent fields")
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("POST", ..#CREATEPATH, .tStatus, .tAnswer, tArgs.%ToJSON(), "application/json")
    Do $$$AssertEquals(tStatus _ " " _ ##class(OcuPilot.Test.LdapEdit).FirstViolation($Get(tAnswer)), "422 Name LDAP.NAME.TAKEN", "and a second create of it is refused as taken")
}

/// <p>AC7, AD-51, AD-53: the delete tool's mint refuses a bare name by <code>LDAP.NAME.FORM</code>
/// (AD-13) even where a configuration answers its target read (<method>FixtureMint</method>), lists
/// the configuration's flags and hosts as removal rows, and its confirm removes it; the list's
/// Delete refuses a bare name the instance resolves, keeping that configuration, and removes another
/// through the screen-action route; each reads back absent, and a Delete of an absent name answers
/// 404.</p>
/// <p>Mutation (Rule 19): <parameter>OcuPilot.Screen.Tool.LdapDelete.WRITETYPE</parameter> set to
/// <code>GET</code> -- the configurations survive and this goes red; and
/// <method>OcuPilot.Screen.Tool.LdapDelete.ScreenActionDelta</method> removed -- the bare name's
/// configuration is deleted and its leg goes red.</p>
Method TestBothCallersDeleteAConfiguration()
{
    Set tAgent = "ocup99agentdelete.invalid"
    Set tScreen = "ocup99screendelete.invalid"
    Set tShort = {}
    Do tShort.%Set("Name", "OcuP99AgentDelete", "string")
    Set tSC = ..FixtureMint(..#DELETE, "OcuP99AgentDelete", tShort, .tProposal, .tHttp, .tFault)
    Do $$$AssertTrue(($Get(tHttp) = 400) && ($ClassMethod(..#HELPER, "Problem", $Get(tFault)) [ ##class(OcuPilot.Api.LdapError).#REASONNAMEFORM), "a bare name is refused at the delete's mint by LDAP.NAME.FORM: " _ $ClassMethod(..#HELPER, "Problem", $Get(tFault)))
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "CreateLdap", tAgent, 72), "a probe is created for the agent's delete")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "CreateLdap", tScreen), "and one for the list's")
    Set tArgs = {}
    Do tArgs.%Set("Name", tAgent, "string")
    Set tSC = $ClassMethod(..#HELPER, "Mint", ..#DELETE, tAgent, tArgs, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the delete is minted: " _ $ClassMethod(..#HELPER, "Problem", $Get(tFault)))
    If $IsObject($Get(tProposal)) {
        Set tRows = ""
        Set tIterator = tProposal.%Get("changed").%GetIterator()
        While tIterator.%GetNext(.tIndex, .tRow) { Set tRows = tRows _ $ListBuild(tRow.%Get("field") _ "=" _ tRow.%Get("before")) }
        Do $$$AssertEquals($ListToString(tRows, ","), "LDAPFlags=72,LDAPHostNames=[""ocup99.invalid""]", "its rows are the flags and hosts that go")
        Set tSC = $ClassMethod(..#CONFIRM, "Confirm", tProposal.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
        Do $$$AssertEquals(tHttp, 200, "the confirm deletes: " _ $Get(tCode))
    }
    Do $$$AssertEquals($ClassMethod(..#PROBE, "LdapExists", tAgent), 0, "the agent's configuration is gone")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "CreateLdap", "ocup99short.com"), "a probe is created whose bare name the instance resolves")
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("POST", ..#ACTIONPATH, .tStatus, .tAnswer, {"action": "delete", "id": "OCUP99SHORT"}.%ToJSON(), "application/json")
    Do $$$AssertTrue((tStatus = 400) && ($Select($IsObject($Get(tAnswer)) && (tAnswer.%GetTypeOf("detail") = "object"): tAnswer.detail.%Get("problem"), 1: "") [ ##class(OcuPilot.Api.LdapError).#REASONNAMEFORM), "the list's Delete of a bare name is refused by LDAP.NAME.FORM: " _ $Select($IsObject($Get(tAnswer)): tAnswer.%ToJSON(), 1: ""))
    Do $$$AssertEquals($ClassMethod(..#PROBE, "LdapExists", "ocup99short.com"), 1, "and the configuration it resolves to is kept")
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("POST", ..#ACTIONPATH, .tStatus, .tAnswer, {"action": "delete", "id": (tScreen)}.%ToJSON(), "application/json")
    Do $$$AssertEquals(tStatus, 200, "the list's Delete answers: " _ $Select($IsObject($Get(tAnswer)): tAnswer.%ToJSON(), 1: ""))
    Do $$$AssertEquals($ClassMethod(..#PROBE, "LdapExists", tScreen), 0, "and its configuration is gone")
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("POST", ..#ACTIONPATH, .tStatus, .tAnswer, {"action": "delete", "id": (tScreen)}.%ToJSON(), "application/json")
    Do $$$AssertEquals(tStatus, 404, "a Delete of an absent name answers 404")
}

/// <p>AD-6, AD-13: a stored dotless name is asked again at the agent's confirm. With
/// <code>ocup99KRB</code> and <code>ocup99krb.com</code> both Kerberos-only and alike, a delete, a
/// change and a search password minted against <code>ocup99KRB</code> are each refused at the
/// confirm by <code>LDAP.NAME.FORM</code> once <code>ocup99KRB</code> is gone, when the vendor's read
/// of that name finds <code>ocup99krb.com</code> by its short form; <code>ocup99krb.com</code> is left
/// as it was.</p>
/// <p>Mutation (Rule 19): drop the <code>ConfirmProblem</code> of
/// <class>OcuPilot.Screen.Tool.LdapDelete</class>, <class>OcuPilot.Screen.Tool.LdapUpdate</class> and
/// <class>OcuPilot.Screen.Tool.LdapPassword</class> -- each leg goes red.</p>
Method TestAConfirmRefusesAStoredNameNowFindingAnother()
{
    Set tDotless = "ocup99KRB"
    Set tOther = "ocup99krb.com"
    For tTool = ..#DELETE, "OcuPilot.Screen.Tool.LdapUpdate", "OcuPilot.Screen.Tool.LdapPassword" {
        Do $$$AssertStatusOK($ClassMethod(..#PROBE, "CreateLdap", tDotless, 128, "UNKNOWNHOST"), tTool _ ": the dotless configuration is created")
        Do $$$AssertStatusOK($ClassMethod(..#PROBE, "CreateLdap", tOther, 128, "UNKNOWNHOST"), tTool _ ": and one its short form finds")
        Set tArgs = {"Name": (tDotless)}
        If tTool = "OcuPilot.Screen.Tool.LdapUpdate" Do tArgs.%Set("Description", "retargeted", "string")
        Set tSC = $ClassMethod(..#HELPER, "Mint", tTool, tDotless, tArgs, .tProposal, .tHttp, .tFault)
        Do $$$AssertStatusOK(tSC, tTool _ ": minted against the stored name: " _ $ClassMethod(..#HELPER, "Problem", $Get(tFault)))
        Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveLdap", tDotless), tTool _ ": the dotless configuration is then removed")
        If $IsObject($Get(tProposal)) {
            Set tSecrets = $Select(tTool = "OcuPilot.Screen.Tool.LdapPassword": {"LDAPSearchPassword": "ocup99"}, 1: "")
            Set tDetail = ""
            Set tSC = $ClassMethod(..#CONFIRM, "Confirm", tProposal.%Get("proposalId"), tSecrets, $Username, .tResult, .tHttp, .tCode, .tDetail)
            Do $$$AssertTrue((tHttp = 400) && $IsObject(tDetail) && (tDetail.%Get("problem") [ ##class(OcuPilot.Api.LdapError).#REASONNAMEFORM), tTool _ ": the confirm is refused by LDAP.NAME.FORM: " _ tHttp _ " " _ $Get(tCode))
        }
        Set tSC = $ClassMethod(..#PROBE, "Read", tOther, .tAfter, "Security.LDAP")
        Do $$$AssertEquals($Select($IsObject($Get(tAfter)): tAfter.%Get("Description"), 1: "absent") _ " " _ $ClassMethod(..#PROBE, "LdapPasswordSet", tOther), "OcuPilot probe 0", tTool _ ": and " _ tOther _ " is left as it was")
        Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveAll"), tTool _ ": the probes are removed")
    }
}

/// <p>The create arguments for <var>pName</var>: a host, the search user and the two base DNs, which
/// a new configuration does not default.</p>
ClassMethod Args(pName As %String) As %DynamicObject
{
    Set tArgs = {"LDAPHostNames": ["h1.invalid"], "LDAPSearchUsername": "CN=ocup99,DC=ocup99new,DC=invalid", "LDAPBaseDN": "DC=ocup99new,DC=invalid", "LDAPBaseDNForGroups": "DC=ocup99new,DC=invalid", "Description": "OcuPilot probe create"}
    Do tArgs.%Set("Name", pName, "string")
    Quit tArgs
}

/// <p>Mint one proposal of the LDAP tool <var>pTool</var> for <var>pName</var> with <var>pArgs</var>
/// through <class>OcuPilot.Test.ProposalMint</class>, whose target read answers
/// <method>OcuPilot.Test.LdapUpdate.Fresh</method> as a stored configuration would, so the tool's own
/// rules are reached whatever the instance resolves <var>pName</var> to: the kernel's target read
/// precedes them, and a bare name that resolves to nothing is refused as absent. The arming is
/// cleared before it returns.</p>
ClassMethod FixtureMint(pTool As %String, pName As %String, pArgs As %DynamicObject, Output pProposal As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pProposal = ""
    Set pFault = ""
    Set pHttpStatus = 0
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurnKey)
    If $$$ISERR(tSC) Quit tSC
    Do ##class(OcuPilot.Test.ProposalFixture).Arm(##class(OcuPilot.Test.LdapUpdate).Fresh())
    Set tSC = ##class(OcuPilot.Test.ProposalMint).Mint($Parameter(pTool, "DESCRIPTORCLASS"), $Parameter(pTool, "TOOLNAME"), $Username, "", tTurnKey, pArgs, "OcuPilot.Kernel.Agent.Limits", .pProposal, .pHttpStatus, .pFault, $ClassMethod(pTool, "Endpoint"), $ClassMethod(pTool, "IdParam"), pName, $ClassMethod(pTool, "IdArgument"), $ClassMethod(pTool, "SettableFields"), pTool)
    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Quit tSC
}

/// <p>The names of the <code>ocup99*</code> configurations on the instance, comma-separated, or
/// <code>""</code>.</p>
ClassMethod Residue() As %String
{
    Set tNames = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tRS = ##class(%ResultSet).%New("Security.LDAPConfigs:List")
        If $$$ISOK(tRS.Execute("*")) {
            While tRS.Next() {
                If $Extract(tRS.GetData(1), 1, 6) = "ocup99" Set tNames = tNames _ $Select(tNames = "": "", 1: ",") _ tRS.GetData(1)
            }
        }
        Set tRS = ""
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tNames
}

}

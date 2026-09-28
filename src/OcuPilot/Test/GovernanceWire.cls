/// <p>Pins <code>GET</code> and <code>PUT /agent/governance</code> over HTTP (Story 14.2, AD-12,
/// AD-39): the read's shape, an accepted write read back with its audit row, and the 403, 409 and
/// 422 refusals, each of which writes nothing.</p>
/// <p><b>What it needs from the environment:</b> the OcuPilot web application on this instance's own
/// web-server port, an account holding <code>%All</code>, and <parameter>ARMINGVARIABLE</parameter>
/// reading <code>1</code>: it creates a principal holding <code>%Admin_Operate:USE</code> and not
/// OcuPilot's administrative resource, and removes it afterwards. Every test starts from no stored
/// policy and puts the policy it found back, asserting the restore.</p>
Class OcuPilot.Test.GovernanceWire Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter APIBASE = "/api/ocupilot";

Parameter PATH = "/agent/governance";

Parameter TOOL = "webapp.list.update";

/// <p>A registered write key whose name ends in a word the audit redaction backstop masks.</p>
Parameter CREDENTIALKEY = "permissions.users.password";

/// <p>The principal holding <code>%Admin_Operate:USE</code> and not OcuPilot's administrative
/// resource.</p>
Parameter OPERATEUSER = "OcuPilotGovernanceOperate";

Parameter OPERATEROLE = "OcuPilotGovernanceOperateRole";

/// <p>The principal's password for this run, generated in <method>OnBeforeAllTests</method>.</p>
Property PreparedPassword As %String;

/// <p>The policy found before the test, put back after it.</p>
Property StoredPolicy [ MultiDimensional ];

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPassword = ""
    Quit $$$OK
}

/// <p>Refuse to run unless <parameter>ARMINGVARIABLE</parameter> arms this class, then create the
/// principal.</p>
Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.GovernanceWire creates and deletes an IRIS user and role on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Set tAdminResource = ##class(OcuPilot.Kernel.State.Base).#ADMINRESOURCE
    Try {
        Set tCode = ##class(OcuPilot.Test.TokenProbe).CodeDatabaseResource()
        Set ..PreparedPassword = "OcuPilotGov" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISERR(tSC) Quit
        Set tResources = tCode _ ":R,%Admin_Operate:U"
        If ##class(Security.Users).Exists(..#OPERATEUSER, .tU, .tUS) {
            Set tSC = ##class(Security.Users).Delete(..#OPERATEUSER)
            If $$$ISERR(tSC) Quit
        }
        If ##class(Security.Roles).Exists(..#OPERATEROLE, .tR, .tRS) {
            Set tSC = ##class(Security.Roles).Delete(..#OPERATEROLE)
            If $$$ISERR(tSC) Quit
        }
        Set tSC = ##class(Security.Roles).Create(..#OPERATEROLE, "OcuPilot test: governance denial principal role (throwaway)", tResources, "")
        If $$$ISERR(tSC) Quit
        Set tSC = ##class(Security.Users).Create(..#OPERATEUSER, ..#OPERATEROLE, ..PreparedPassword, "OcuPilot governance test principal (throwaway)", "", "", "", 0, 1, "Created by OcuPilot.Test.GovernanceWire; deleted in OnAfterAllTests")
        If $$$ISERR(tSC) Quit
        Set tHoldsOperate = ($SYSTEM.Security.CheckUserPermission(..#OPERATEUSER, "%Admin_Operate", "USE") = 1)
        Set tLacksOcuPilot = ($SYSTEM.Security.CheckUserPermission(..#OPERATEUSER, tAdminResource, "USE") '= 1)
        If 'tHoldsOperate || 'tLacksOcuPilot {
            Set tSC = $$$ERROR($$$GeneralError, "Setup could not confirm the principal's pairs: holds %Admin_Operate " _ tHoldsOperate _ ", lacks " _ tAdminResource _ " " _ tLacksOcuPilot)
        }
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Remove the principal and its role, and return a failing status if either survives.</p>
Method OnAfterAllTests() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISERR(tSC) Quit
        If ##class(Security.Users).Exists(..#OPERATEUSER, .tU, .tUS) Do ##class(Security.Users).Delete(..#OPERATEUSER)
        If ##class(Security.Roles).Exists(..#OPERATEROLE, .tR, .tRS) Do ##class(Security.Roles).Delete(..#OPERATEROLE)
        If ##class(Security.Users).Exists(..#OPERATEUSER, .tU2, .tUS2) || ##class(Security.Roles).Exists(..#OPERATEROLE, .tR2, .tRS2) {
            Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.GovernanceWire left its principal or its role on the instance")
        }
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

Method OnBeforeOneTest() As %Status
{
    Kill ..StoredPolicy
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tRows)
    If $$$ISERR(tSC) Quit tSC
    Merge ..StoredPolicy = tRows
    Quit ##class(OcuPilot.Test.GovernanceFixture).Clear()
}

Method OnAfterOneTest() As %Status
{
    Kill tRows
    Merge tRows = ..StoredPolicy
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows)
    Do $$$AssertStatusOK(tSC, "the policy found before the test is put back")
    Do $$$AssertTrue(##class(OcuPilot.Test.GovernanceFixture).Matches(.tRows), "and reads back as it was")
    Quit $$$OK
}

/// <p>One request to the policy route as <var>pUser</var> (the suite's own account when empty),
/// answering the status and the parsed body, and asserting one JSON envelope.</p>
Method Call(pMethod As %String, pBody As %String, Output pStatus As %Integer, Output pAnswer As %DynamicObject, pUser As %String = "", pPassword As %String = "") As %Status
{
    Set pAnswer = ""
    Set tUser = $Select(pUser '= "": pUser, 1: ##class(OcuPilot.Test.Http).GetTestUsername())
    Set tPassword = $Select(pUser '= "": pPassword, 1: ##class(OcuPilot.Test.Http).GetTestPassword())
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest(pMethod, ..#APIBASE _ ..#PATH, tUser, tPassword, .pStatus, .tText, .tHeaders, pBody, "application/json")
    Do $$$AssertStatusOK(tSC, pMethod _ ": the request completes")
    Do $$$AssertTrue($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", pMethod _ ": as JSON")
    Do $$$AssertEquals($Get(tText) [ "}{", 0, pMethod _ ": in exactly one envelope")
    Try {
        Set pAnswer = ##class(%DynamicObject).%FromJSON(tText)
    } Catch {
        Set pAnswer = {}
    }
    Quit tSC
}

/// <p>The entry <var>pAnswer</var>'s <code>keys</code> carries for <var>pKey</var>, or
/// <code>""</code>.</p>
ClassMethod Entry(pAnswer As %DynamicObject, pKey As %String) As %DynamicObject
{
    If '$IsObject(pAnswer) || (pAnswer.%GetTypeOf("keys") '= "array") Quit ""
    Set tIterator = pAnswer.%Get("keys").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tEntry) {
        If tEntry.%Get("key") = pKey Quit
    }
    If '$IsObject($Get(tEntry)) || (tEntry.%Get("key") '= pKey) Quit ""
    Quit tEntry
}

/// <p>The read answers the preset, the version and one entry per registered write key in name
/// order, each with its baseline, setting, effect and source; the purge reads disabled by the
/// baseline.</p>
Method TestTheReadAnswersEveryWriteKey()
{
    Do ..Call("GET", "", .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus, 200, "the read answers 200")
    Do $$$AssertEquals(tAnswer.%Get("preset") _ "|" _ tAnswer.%Get("rowVersion"), "|0", "no preset, at version 0")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.Governance.Policy).WriteKeys(.tKeys), "the write keys are read")
    Set tExpected = ""
    Set tKey = ""
    For {
        Set tKey = $Order(tKeys(tKey))
        If tKey = "" Quit
        Set tExpected = tExpected _ $ListBuild(tKey)
    }
    Set tRead = ""
    Set tIterator = tAnswer.%Get("keys").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tEntry) { Set tRead = tRead _ $ListBuild(tEntry.%Get("key")) }
    Do $$$AssertEquals($ListToString(tRead), $ListToString(tExpected), "one entry per registered write key, in name order")
    Set tPurge = ..Entry(tAnswer, "security.auditing.purge")
    Do $$$AssertEquals($Select($IsObject(tPurge): tPurge.%ToJSON(), 1: ""), "{""key"":""security.auditing.purge"",""baseline"":""disabled"",""setting"":""inherit"",""enabled"":false,""source"":""baseline""}", "the purge is disabled by the baseline")
    Set tTool = ..Entry(tAnswer, ..#TOOL)
    Do $$$AssertEquals($Select($IsObject(tTool): tTool.%ToJSON(), 1: ""), "{""key"":""" _ ..#TOOL _ """,""baseline"":""enabled"",""setting"":""inherit"",""enabled"":true,""source"":""baseline""}", "and a key the baseline lists true reads enabled by it")
}

/// <p>AC1: a write naming <parameter>TOOL</parameter> disabled under <code>read-only</code> is
/// answered and read back, the version moves, and one audit row names the actor, the target and
/// the old and new value of the preset and of the key.</p>
/// <p>Mutation (Rule 19): drop <method>OcuPilot.Api.Governance.RecordAudit</method>'s call -> the
/// audit leg goes red; name each key's entry by the key -> the credential-word leg goes red.</p>
Method TestAnAcceptedWriteIsReadBackAndAudited()
{
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    ; webapp.list.create is named and stays inherit, so the audit row must leave it out.
    Do ..Call("PUT", "{""preset"":""read-only"",""settings"":{""" _ ..#TOOL _ """:""disabled"",""webapp.list.create"":""inherit"",""" _ ..#CREDENTIALKEY _ """:""enabled""},""rowVersion"":0}", .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus, 200, "the write is accepted: " _ tAnswer.%ToJSON())
    Do $$$AssertEquals(tAnswer.%Get("preset") _ "|" _ tAnswer.%Get("rowVersion"), "read-only|1", "the answer carries the stored preset at version 1")
    Do ..Call("GET", "", .tStatus, .tRead)
    Set tEntry = ..Entry(tRead, ..#TOOL)
    Do $$$AssertEquals($Select($IsObject(tEntry): tEntry.%Get("setting") _ "|" _ tEntry.%Get("enabled") _ "|" _ tEntry.%Get("source"), 1: ""), "disabled|0|setting", "the read gives the key back disabled by its setting")
    Set tOther = ..Entry(tRead, "webapp.list.create")
    Do $$$AssertEquals($Select($IsObject(tOther): tOther.%Get("enabled") _ "|" _ tOther.%Get("source"), 1: ""), "0|preset", "and another write disabled by the preset")

    Set tRows = ##class(OcuPilot.Test.AuditEvent).RowsCarrying(tSince, ##class(OcuPilot.Kernel.Audit.Event).EventNameFor(1), """verb"":""governance""", .tData, ..#TOOL)
    Do $$$AssertEquals(tRows, 1, "one audit row records the write")
    Do $$$AssertTrue(tData [ ("""actor"":""" _ ##class(OcuPilot.Test.Http).GetTestUsername() _ """"), "naming the actor: " _ tData)
    Do $$$AssertTrue(tData [ """type"":""agent-policy""", "and the target")
    Do $$$AssertTrue(tData [ """preset"":{""old"":"""",""new"":""read-only""}", "and the preset's old and new value")
    Do $$$AssertTrue(tData [ ("{""tool"":""" _ ..#TOOL _ """,""old"":""inherit"",""new"":""disabled""}"), "and the key's old and new value: " _ tData)
    Do $$$AssertTrue(tData [ ("{""tool"":""" _ ..#CREDENTIALKEY _ """,""old"":""inherit"",""new"":""enabled""}"), "and a key ending in a credential word is recorded, not masked: " _ tData)
    Do $$$AssertTrue(tData '[ """tool"":""webapp.list.create""", "and no entry for a key the write named without changing it")
}

/// <p>A write leaves every key its <code>settings</code> does not name as it was: a key disabled by
/// one write still reads disabled after a second write that names no key.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Kernel.State.Policy.GuardedApply</method> removes every
/// key row before storing -> this goes red.</p>
Method TestAKeyTheWriteDoesNotNameIsLeftAsItIs()
{
    Do ..Call("PUT", "{""preset"":"""",""settings"":{""" _ ..#TOOL _ """:""disabled""},""rowVersion"":0}", .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus, 200, "a first write disables the key: " _ tAnswer.%ToJSON())
    Set tVersion = +tAnswer.%Get("rowVersion")
    Do ..Call("PUT", "{""preset"":""full"",""settings"":{},""rowVersion"":" _ tVersion _ "}", .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus, 200, "a second write naming no key is accepted: " _ tAnswer.%ToJSON())
    Do ..Call("GET", "", .tStatus, .tRead)
    Set tEntry = ..Entry(tRead, ..#TOOL)
    Do $$$AssertEquals(tRead.%Get("preset") _ "|" _ $Select($IsObject(tEntry): tEntry.%Get("setting") _ "|" _ tEntry.%Get("source"), 1: ""), "full|disabled|setting", "the key keeps the setting the first write stored")
}

/// <p>A write carrying a version the policy has moved past is refused 409
/// <code>STATE.CONFLICT</code> and writes nothing.</p>
Method TestAStaleVersionIsRefused()
{
    Do ..Call("PUT", "{""preset"":""full"",""settings"":{},""rowVersion"":0}", .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus, 200, "a first write moves the version: " _ tAnswer.%ToJSON())
    Do ..Call("PUT", "{""preset"":""read-only"",""settings"":{""" _ ..#TOOL _ """:""disabled""},""rowVersion"":0}", .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus _ "|" _ tAnswer.%Get("code"), "409|" _ ##class(OcuPilot.Api.Error).#STATECONFLICT, "a write at the old version is refused")
    Do ..Call("GET", "", .tStatus, .tRead)
    Set tEntry = ..Entry(tRead, ..#TOOL)
    Do $$$AssertEquals(tRead.%Get("preset") _ "|" _ $Select($IsObject(tEntry): tEntry.%Get("setting"), 1: ""), "full|inherit", "and nothing it carried was written")
}

/// <p>AC8 and the matrix's bad bodies: an unknown member, a bad preset or setting, and a missing
/// version are 422 <code>GOVERNANCE.BODY</code>; the ledger, the agent marker and a read tool are
/// 422 <code>GOVERNANCE.KEY</code>; each carries <code>{field, code, reason}</code> violations and
/// writes nothing.</p>
/// <p>Mutation (Rule 19): admit read keys in <method>OcuPilot.Api.Governance.Validate</method> ->
/// the read-tool leg goes red.</p>
Method TestABadBodyOrKeyIsRefusedAndWritesNothing()
{
    Set tBodyCode = ##class(OcuPilot.Api.Error).#GOVERNANCEBODY
    Set tKeyCode = ##class(OcuPilot.Api.Error).#GOVERNANCEKEY
    For tCase = $ListBuild("{""preset"":"""",""settings"":{},""rowVersion"":0,""extra"":1}", tBodyCode, "extra"), $ListBuild("{""preset"":""open"",""settings"":{},""rowVersion"":0}", tBodyCode, "preset"), $ListBuild("{""preset"":"""",""settings"":{""webapp.list.update"":""maybe""},""rowVersion"":0}", tBodyCode, "settings.webapp.list.update"), $ListBuild("{""preset"":"""",""settings"":{}}", tBodyCode, "rowVersion"), $ListBuild("{""preset"":"""",""settings"":{""agent.ledger"":""disabled""},""rowVersion"":0}", tKeyCode, "settings.agent.ledger"), $ListBuild("{""preset"":"""",""settings"":{""agent.marker"":""disabled""},""rowVersion"":0}", tKeyCode, "settings.agent.marker"), $ListBuild("{""preset"":"""",""settings"":{""logs.errors.read"":""disabled""},""rowVersion"":0}", tKeyCode, "settings.logs.errors.read") {
        Do ..Call("PUT", $List(tCase, 1), .tStatus, .tAnswer)
        Do $$$AssertEquals(tStatus _ "|" _ tAnswer.%Get("code"), "422|" _ $List(tCase, 2), $List(tCase, 1) _ ": refused with " _ $List(tCase, 2) _ ": " _ tAnswer.%ToJSON())
        Set tViolation = ""
        If $IsObject(tAnswer.%Get("detail")) && (tAnswer.%Get("detail").%GetTypeOf("violations") = "array") Set tViolation = tAnswer.%Get("detail").%Get("violations").%Get(0)
        Do $$$AssertEquals($Select($IsObject(tViolation): tViolation.%Get("field") _ "|" _ tViolation.%Get("code") _ "|" _ (tViolation.%Get("reason") '= ""), 1: ""), $List(tCase, 3) _ "|" _ $List(tCase, 2) _ "|1", "on the field it names, with a reason")
    }
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tNow), "the policy reads")
    Do $$$AssertEquals($Order(tNow("")), "", "and nothing was written")
}

/// <p>The matrix's non-administrator: a principal holding <code>%Admin_Operate:USE</code> alone is
/// refused both routes 403 <code>AUTH.NOPRIVILEGE</code> naming <code>OcuPilotAdmin:USE</code>, and
/// writes nothing.</p>
Method TestANonAdministratorIsRefusedBothRoutes()
{
    Set tPair = ##class(OcuPilot.Kernel.State.Base).#ADMINRESOURCE _ ":USE"
    For tMethod = "GET", "PUT" {
        Set tBody = $Select(tMethod = "PUT": "{""preset"":""read-only"",""settings"":{},""rowVersion"":0}", 1: "")
        Do ..Call(tMethod, tBody, .tStatus, .tAnswer, ..#OPERATEUSER, ..PreparedPassword)
        Do $$$AssertEquals(tStatus _ "|" _ tAnswer.%Get("code"), "403|AUTH.NOPRIVILEGE", tMethod _ ": refused for privilege")
        Do $$$AssertEquals($Select($IsObject(tAnswer.%Get("detail")): tAnswer.%Get("detail").%Get("failedPair"), 1: ""), tPair, tMethod _ ": naming " _ tPair)
    }
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tNow), "the policy reads")
    Do $$$AssertEquals($Order(tNow("")), "", "and nothing was written")
}

}

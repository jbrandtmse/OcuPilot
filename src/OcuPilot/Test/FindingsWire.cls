/// <p><code>GET /api/ocupilot/ui/findings</code> over HTTP (Story 16.21), against the instance's own
/// state and the <b>real</b> <code>$System.Security.Check</code> (AD-8, AD-10, AD-29):</p>
/// <ul>
/// <li>an unauthenticated probe application whose application role is <code>%DB_USER</code> is a
/// <code>webapp-open</code> finding, and the same application holding a role with only
/// <code>%DB_USER:R</code> is not;</li>
/// <li>the demo fixture's task, suspended after an error, is a <code>task-error</code> finding;</li>
/// <li><code>_SYSTEM</code> reads <code>refused</code> with the code and sentence the impact route
/// answers for removing <code>%All</code> from it, and <code>SuperUser</code> reads the agent's
/// fix;</li>
/// <li>a principal without <code>%Admin_Secure:USE</code> reads the five security checks
/// <code>unchecked</code> naming that pair, and holds no security finding.</li>
/// </ul>
/// <p><b>It creates a web application, a role and an account, so it runs on a throwaway container
/// only</b> (<file>scripts/ci-throwaway.sh</file>), and <method>OnBeforeAllTests</method> refuses
/// anywhere <parameter>ARMINGVARIABLE</parameter> does not arm it. It needs the demo fixture
/// (<code>OCUPILOT_DEMO</code>). Everything it creates is removed in
/// <method>OnAfterAllTests</method>, which fails if anything survives.</p>
Class OcuPilot.Test.FindingsWire Extends %UnitTest.TestCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter FINDINGSPATH As %String = "/api/ocupilot/ui/findings";

Parameter IMPACTPATH As %String = "/api/ocupilot/screens/:screen/impact";

Parameter PROBEAPP = "/csp/ocuprobe1621";

/// <p>The probe application's description, which marks it as this suite's own.</p>
Parameter PROBEMARKER = "OcuPilot findings probe (throwaway)";

/// <p>The probe role holding only <code>%DB_USER:R</code>.</p>
Parameter READROLE = "OcuFindingsReadRole";

/// <p>The least-privileged principal, and its role: the install namespace's code, the Databases
/// screen's two pairs, and no <code>%Admin_Secure</code>.</p>
Parameter LOWUSER = "OcuFindingsLow";

Parameter LOWROLE = "OcuFindingsLowRole";

Parameter USERLIST = "OcuPilot.Screen.Descriptor.UserList";

/// <p>The account's password for this run, generated in <method>OnBeforeAllTests</method>.</p>
Property PreparedPassword As %String;

/// <p>Whether <method>OnBeforeAllTests</method> read back the principal's pairs.</p>
Property PreparedSetupOk As %Boolean [ InitialExpression = 0 ];

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPassword = ""
    Set ..PreparedSetupOk = 0
    Quit $$$OK
}

/// <p>Refuse to run unless armed, then create the probe role and the least-privileged principal and
/// read the principal's pairs back.</p>
Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.FindingsWire creates and deletes a web application, a role and a user on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set tInstallNs = ##class(OcuPilot.Install.Installer).ResolveNamespace()
        Set ..PreparedPassword = "OcuFindings" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISERR(tSC) Quit
        Set tNsObj = ##class(Config.Namespaces).Open(tInstallNs)
        Set tDbObj = ##class(Config.Databases).Open(tNsObj.Routines)
        Set tCodeRead = ##class(SYS.Database).%OpenId(tDbObj.Directory).ResourceName _ ":R"
        Set tSC = ..EnsureRole(..#READROLE, "%DB_USER:R")
        If $$$ISERR(tSC) Quit
        Set tSC = ..EnsureRole(..#LOWROLE, tCodeRead _ ",%Admin_Manage:U,%DB_IRISSYS:R")
        If $$$ISERR(tSC) Quit
        If ##class(Security.Users).Exists(..#LOWUSER) {
            Set tSC = ##class(Security.Users).Delete(..#LOWUSER)
            If $$$ISERR(tSC) Quit
        }
        Set tSC = ##class(Security.Users).Create(..#LOWUSER, ..#LOWROLE, ..PreparedPassword, "OcuPilot findings test principal (throwaway)", "", "", "", 0, 1, "Created by OcuPilot.Test.FindingsWire; deleted in OnAfterAllTests")
        If $$$ISERR(tSC) Quit
        Set ..PreparedSetupOk = ($SYSTEM.Security.CheckUserPermission(..#LOWUSER, "%Admin_Secure", "USE") '= 1) && ($SYSTEM.Security.CheckUserPermission(..#LOWUSER, "%Admin_Manage", "USE") = 1)
        If '..PreparedSetupOk Set tSC = $$$ERROR($$$GeneralError, "Setup could not confirm the principal's pairs")
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Remove the probe application, the two roles and the account, and fail if any survives.</p>
Method OnAfterAllTests() As %Status
{
    Set tSC = ..RemoveProbe()
    Set tOrigNS = $NAMESPACE
    Try {
        Set tSwitchSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISERR(tSwitchSC) {
            Set tSC = tSwitchSC
            Quit
        }
        If ##class(Security.Users).Exists(..#LOWUSER) Do ##class(Security.Users).Delete(..#LOWUSER)
        For tRole = ..#LOWROLE, ..#READROLE {
            If ##class(Security.Roles).Exists(tRole) Do ##class(Security.Roles).Delete(tRole)
        }
        Set tLeft = ""
        If ##class(Security.Users).Exists(..#LOWUSER) Set tLeft = tLeft _ " user " _ ..#LOWUSER
        For tRole = ..#LOWROLE, ..#READROLE {
            If ##class(Security.Roles).Exists(tRole) Set tLeft = tLeft _ " role " _ tRole
        }
        If ##class(Security.Applications).Exists(..#PROBEAPP) Set tLeft = tLeft _ " application " _ ..#PROBEAPP
        If tLeft '= "" Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.FindingsWire teardown left:" _ tLeft)
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Create or re-grant one role. <b>Caller contract:</b> <code>$NAMESPACE</code> is
/// <code>%SYS</code>.</p>
Method EnsureRole(pRole As %String, pResources As %String) As %Status
{
    If ##class(Security.Roles).Exists(pRole) {
        Set tProps("Resources") = pResources
        Set tProps("GrantedRoles") = ""
        Quit ##class(Security.Roles).Modify(pRole, .tProps)
    }
    Quit ##class(Security.Roles).Create(pRole, "OcuPilot findings probe role (throwaway)", pResources, "")
}

/// <p>Create <parameter>PROBEAPP</parameter> afresh, reachable without signing in, with
/// <var>pRole</var> as its one application role.</p>
ClassMethod EnsureProbe(pRole As %String) As %Status
{
    Set tSC = ..RemoveProbe()
    If $$$ISERR(tSC) Quit tSC
    Set tOrigNS = $NAMESPACE
    Try {
        Set tNamespace = $NAMESPACE
        Set $NAMESPACE = "%SYS"
        Set tProps("NameSpace") = tNamespace
        Set tProps("Description") = ..#PROBEMARKER
        Set tProps("AutheEnabled") = 64
        Set tProps("Enabled") = 1
        Set tProps("MatchRoles") = ":" _ pRole
        Set tSC = ##class(Security.Applications).Create(..#PROBEAPP, .tProps)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Delete <parameter>PROBEAPP</parameter> when it is this suite's own.</p>
ClassMethod RemoveProbe() As %Status
{
    Quit ##class(OcuPilot.Test.WebAppSave).RemoveApp(..#PROBEAPP, ..#PROBEMARKER)
}

/// <p>One findings read as <var>pUser</var>, or as the suite's own account.</p>
Method Findings(pUser As %String = "", Output pStatus As %Integer, Output pHeaders) As %DynamicObject
{
    Set tUser = $Select(pUser = "": ##class(OcuPilot.Test.Http).GetTestUsername(), 1: pUser)
    Set tPassword = $Select(pUser = "": ##class(OcuPilot.Test.Http).GetTestPassword(), 1: ..PreparedPassword)
    Quit ..Get(..#FINDINGSPATH, tUser, tPassword, .pStatus, .pHeaders)
}

/// <p>One <code>GET</code> of <var>pPath</var>, its body parsed, or <code>""</code>.</p>
ClassMethod Get(pPath As %String, pUser As %String, pPassword As %String, Output pStatus As %Integer, Output pHeaders) As %DynamicObject
{
    Set pStatus = 0
    Set tAnswer = ""
    Do ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", pPath, pUser, pPassword, .pStatus, .tRaw, .pHeaders)
    Try {
        Set tAnswer = ##class(%DynamicAbstractObject).%FromJSON($ZConvert(tRaw, "I", "UTF8"))
    } Catch {
        Set tAnswer = ""
    }
    Quit tAnswer
}

/// <p>The status <var>pAnswer</var> reports for <var>pCheck</var>, or <code>""</code>.</p>
ClassMethod CheckStatus(pAnswer As %DynamicObject, pCheck As %String) As %String
{
    Set tStatus = ""
    If '$IsObject(pAnswer) || (pAnswer.%GetTypeOf("checks") '= "array") Quit tStatus
    Set tIterator = pAnswer.%Get("checks").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If tRow.%Get("check") = pCheck Set tStatus = tRow.%Get("status") Quit
    }
    Quit tStatus
}

/// <p><var>pAnswer</var>'s finding for <var>pCheck</var> naming <var>pName</var>, or
/// <code>""</code>.</p>
ClassMethod Finding(pAnswer As %DynamicObject, pCheck As %String, pName As %String) As %DynamicObject
{
    Set tFound = ""
    If '$IsObject(pAnswer) || (pAnswer.%GetTypeOf("findings") '= "array") Quit tFound
    Set tIterator = pAnswer.%Get("findings").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tFinding) {
        If (tFinding.%Get("check") = pCheck) && (tFinding.%Get("name") = pName) Set tFound = tFinding Quit
    }
    Quit tFound
}

/// <p>An unauthenticated application whose application role writes a database is a finding; the
/// same application holding only read is not.</p>
/// <p>Mutation: return 0 from the <code>W</code> arm of
/// <method>OcuPilot.Kernel.Shell.Findings.Privileged</method> -&gt; the first leg goes red.</p>
Method TestAnOpenApplicationWritingADatabaseIsAFindingAndReadOnlyIsNot()
{
    Do $$$AssertStatusOK(..EnsureProbe("%DB_USER"), "the probe application is created with %DB_USER")
    Set tAnswer = ..Findings(, .tStatus, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "the findings are read")
    Do $$$AssertTrue($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", "as application/json")
    Do $$$AssertTrue($IsObject(tAnswer) && (tAnswer.%GetTypeOf("checks") = "array") && (tAnswer.%GetTypeOf("findings") = "array"), "carrying checks and findings")
    Set tFinding = ..Finding(tAnswer, "webapp-open", ..#PROBEAPP)
    Do $$$AssertTrue($IsObject(tFinding), "the probe application is a finding: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: ""))
    If $IsObject(tFinding) Do $$$AssertEquals(tFinding.%Get("route") _ " " _ tFinding.%Get("id") _ " " _ tFinding.%Get("fix"), "web-applications/list " _ ..#PROBEAPP _ " agent", "on its list, by name, with the agent's fix")

    Do $$$AssertStatusOK(..EnsureProbe(..#READROLE), "the probe application is recreated with a read-only role")
    Set tAnswer = ..Findings(, .tStatus)
    Do $$$AssertEquals(tStatus, 200, "the findings are read again")
    Do $$$AssertEquals(..CheckStatus(tAnswer, "webapp-open"), "checked", "and the check was read")
    Do $$$AssertEquals(..Finding(tAnswer, "webapp-open", ..#PROBEAPP), "", "read-only is not a finding")
    Do $$$AssertStatusOK(..RemoveProbe(), "the probe application is removed")
}

/// <p>The demo fixture's task, suspended after an error, is a <code>task-error</code> finding on
/// its details.</p>
Method TestTheDemoTaskSuspendedAfterAnErrorIsAFinding()
{
    Set tName = ##class(OcuPilot.Install.Fixture).ResolvedPrefix("") _ " nightly purge"
    Set tAnswer = ..Findings(, .tStatus)
    Set tFinding = ..Finding(tAnswer, "task-error", tName)
    Do $$$AssertTrue($IsObject(tFinding), "the demo task is a finding")
    If $IsObject(tFinding) Do $$$AssertEquals(tFinding.%Get("route") _ " " _ tFinding.%Get("fix"), "tasks/schedule/details agent", "on its details, with the agent's fix")
}

/// <p><code>_SYSTEM</code>'s <code>%All</code> finding is refused with the code and sentence the
/// impact route answers for the same removal.</p>
/// <p>Mutation: answer a hand-written sentence in place of
/// <method>OcuPilot.Kernel.Proposal.Prohibited.ReasonFor</method> in
/// <method>OcuPilot.Kernel.Shell.Findings.AllHolders</method> -&gt; this goes red.</p>
Method TestSystemIsRefusedExactlyAsTheImpactRouteRefusesIt()
{
    Set tAnswer = ..Findings(, .tStatus)
    Set tFinding = ..Finding(tAnswer, "all-holder", "_SYSTEM")
    Do $$$AssertTrue($IsObject(tFinding), "_SYSTEM is an %All finding")
    If '$IsObject(tFinding) Quit
    Do $$$AssertEquals(tFinding.%Get("fix"), "refused", "with no fix offered")
    Set tPath = $Replace(..#IMPACTPATH, ":screen", $ClassMethod(..#USERLIST, "ToolIdentifier")) _ "?action=remove-role&id=_SYSTEM&value=" _ $ZConvert("%All", "O", "URL")
    Set tImpact = ..Get(tPath, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tImpactStatus)
    Do $$$AssertEquals(tImpactStatus, 200, "the impact route answers")
    Set tRefused = ""
    If $IsObject(tImpact) && $IsObject(tImpact.%Get("impact")) Set tRefused = tImpact.%Get("impact").%Get("refused")
    Do $$$AssertTrue($IsObject(tRefused), "and refuses the removal")
    If '$IsObject(tRefused) Quit
    Do $$$AssertEquals(tFinding.%Get("refused").%Get("code"), tRefused.%Get("code"), "the two answer one code")
    Do $$$AssertEquals(tFinding.%Get("refused").%Get("reason"), tRefused.%Get("reason"), "and one sentence")
    Set tSuper = ..Finding(tAnswer, "all-holder", "SuperUser")
    Do $$$AssertTrue($IsObject(tSuper), "SuperUser is an %All finding")
    If '$IsObject(tSuper) Quit
    Do $$$AssertEquals(tSuper.%Get("fix") _ " " _ tSuper.%GetTypeOf("refused"), "agent unassigned", "and one the prohibited set does not refuse offers the agent's fix")
}

/// <p>A principal without <code>%Admin_Secure:USE</code> reads the five security checks unchecked,
/// naming that pair, and holds no security finding; the checks its pairs allow are read.</p>
/// <p>Mutation: skip the gate in <method>OcuPilot.Kernel.Shell.Findings.Rows</method> -&gt; the
/// security checks read <code>checked</code> or <code>failed</code> and this goes red.</p>
Method TestACallerWithoutTheSecurityPairReadsThoseChecksUnchecked()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup confirmed the principal's pairs")
    Set tAnswer = ..Findings(..#LOWUSER, .tStatus)
    Do $$$AssertEquals(tStatus, 200, "the findings answer; an unreadable check is never a 403")
    If '$IsObject(tAnswer) Quit
    Set tUnchecked = 0
    Set tIterator = tAnswer.%Get("checks").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If tRow.%Get("group") = "security" {
            Do $$$AssertEquals(tRow.%Get("status") _ " " _ tRow.%Get("pair"), "unchecked %Admin_Secure:USE", tRow.%Get("check") _ " is unchecked, naming the pair")
            Set tUnchecked = tUnchecked + 1
        }
        If tRow.%Get("check") = "database-dismounted" Do $$$AssertEquals(tRow.%Get("status"), "checked", "a check its pairs allow is read")
    }
    Do $$$AssertEquals(tUnchecked, 5, "all five security checks")
    Set tSecurity = 0
    Set tIterator = tAnswer.%Get("findings").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tFinding) {
        If tFinding.%Get("group") = "security" Set tSecurity = tSecurity + 1
    }
    Do $$$AssertEquals(tSecurity, 0, "and no security finding")
}

}

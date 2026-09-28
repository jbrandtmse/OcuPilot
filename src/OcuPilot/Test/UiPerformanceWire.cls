/// <p><code>GET /api/ocupilot/ui/performance</code> over HTTP (Story 16.18): the performance row's
/// read, as the suite's own credentials and as three least-privileged principals, against the
/// <b>real</b> <code>$System.Security.Check</code> (AD-8, AD-29).</p>
/// <ul>
/// <li>The suite's own account and a principal holding both pairs read five numbers, as JSON.</li>
/// <li>A principal without <code>%Admin_Operate:USE</code> is refused 403
/// <code>AUTH.NOPRIVILEGE</code> naming that pair; one without <code>%DB_IRISSYS:READ</code> is
/// refused naming that one.</li>
/// </ul>
/// <p><b>It creates security principals, so it runs on a throwaway container only</b>
/// (<file>scripts/ci-throwaway.sh</file>), and <method>OnBeforeAllTests</method> refuses anywhere
/// <parameter>ARMINGVARIABLE</parameter> does not arm it. Each principal holds read on the install
/// namespace's code database and one administrative resource, which clears the API's own
/// administrative gate: the principal lacking <code>%Admin_Operate</code> holds
/// <code>%Admin_Secure:USE</code> for that. Their password is generated for the run and never
/// written to source; all three are deleted in <method>OnAfterAllTests</method>.</p>
Class OcuPilot.Test.UiPerformanceWire Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, and the one value that arms it:
/// <code>1</code>.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

/// <p>The route under test, from the origin root.</p>
Parameter PERFORMANCEPATH As %String = "/api/ocupilot/ui/performance";

/// <p>The verb it answers.</p>
Parameter READVERB As %String = "GET";

/// <p>The five members the body carries. The wire contract, spelled here.</p>
Parameter WIREMEMBERS As %String = "cacheEfficiency,globalReferencesPerSecond,globalUpdatesPerSecond,diskReadsPerSecond,diskWritesPerSecond";

/// <p>The principal holding both pairs.</p>
Parameter BOTHUSER = "OcuPilotPerfBoth";

/// <p>See <parameter>BOTHUSER</parameter>.</p>
Parameter BOTHROLE = "OcuPilotPerfBothRole";

/// <p>The principal holding <code>%DB_IRISSYS:READ</code> and <code>%Admin_Secure:USE</code>, not
/// <code>%Admin_Operate:USE</code>.</p>
Parameter NOOPERATEUSER = "OcuPilotPerfNoOperate";

/// <p>See <parameter>NOOPERATEUSER</parameter>.</p>
Parameter NOOPERATEROLE = "OcuPilotPerfNoOperateRole";

/// <p>The principal holding <code>%Admin_Operate:USE</code>, not
/// <code>%DB_IRISSYS:READ</code>.</p>
Parameter NOSYSUSER = "OcuPilotPerfNoSys";

/// <p>See <parameter>NOSYSUSER</parameter>.</p>
Parameter NOSYSROLE = "OcuPilotPerfNoSysRole";

/// <p>The three accounts' password for this run, generated in <method>OnBeforeAllTests</method>.</p>
Property PreparedPassword As %String;

/// <p>Whether <method>OnBeforeAllTests</method> read back each account's pairs.</p>
Property PreparedSetupOk As %Boolean [ InitialExpression = 0 ];

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPassword = ""
    Set ..PreparedSetupOk = 0
    Quit $$$OK
}

/// <p>Refuse to run unless this instance is armed for throwaway principals, then create the three
/// principals and read their pairs back.</p>
Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.UiPerformanceWire creates and deletes IRIS users and roles on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so no principal was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set tInstallNs = ##class(OcuPilot.Install.Installer).ResolveNamespace()
        Set ..PreparedPassword = "OcuPilotPerf" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"

        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISERR(tSC) Quit

        Set tNsObj = ##class(Config.Namespaces).Open(tInstallNs)
        If '$IsObject(tNsObj) {
            Set tSC = $$$ERROR($$$GeneralError, "Could not open namespace configuration for " _ tInstallNs)
            Quit
        }
        Set tDbObj = ##class(Config.Databases).Open(tNsObj.Routines)
        If '$IsObject(tDbObj) {
            Set tSC = $$$ERROR($$$GeneralError, "Could not open the routine database " _ tNsObj.Routines)
            Quit
        }
        Set tSysDb = ##class(SYS.Database).%OpenId(tDbObj.Directory)
        If '$IsObject(tSysDb) {
            Set tSC = $$$ERROR($$$GeneralError, "Could not open SYS.Database for the routine database directory")
            Quit
        }
        Set tCodeRead = tSysDb.ResourceName _ ":R"

        Set tSC = ..EnsurePrincipal(..#BOTHROLE, ..#BOTHUSER, tCodeRead _ ",%Admin_Operate:U,%DB_IRISSYS:R", ..PreparedPassword)
        If $$$ISERR(tSC) Quit
        Set tSC = ..EnsurePrincipal(..#NOOPERATEROLE, ..#NOOPERATEUSER, tCodeRead _ ",%DB_IRISSYS:R,%Admin_Secure:U", ..PreparedPassword)
        If $$$ISERR(tSC) Quit
        Set tSC = ..EnsurePrincipal(..#NOSYSROLE, ..#NOSYSUSER, tCodeRead _ ",%Admin_Operate:U", ..PreparedPassword)
        If $$$ISERR(tSC) Quit

        Set tBoth = ($SYSTEM.Security.CheckUserPermission(..#BOTHUSER, "%Admin_Operate", "USE") = 1) && ($SYSTEM.Security.CheckUserPermission(..#BOTHUSER, "%DB_IRISSYS", "READ") = 1)
        Set tNoOperate = ($SYSTEM.Security.CheckUserPermission(..#NOOPERATEUSER, "%Admin_Operate", "USE") '= 1) && ($SYSTEM.Security.CheckUserPermission(..#NOOPERATEUSER, "%DB_IRISSYS", "READ") = 1)
        Set tNoSys = ($SYSTEM.Security.CheckUserPermission(..#NOSYSUSER, "%Admin_Operate", "USE") = 1) && ($SYSTEM.Security.CheckUserPermission(..#NOSYSUSER, "%DB_IRISSYS", "READ") '= 1)
        Set ..PreparedSetupOk = tBoth && tNoOperate && tNoSys
        If '..PreparedSetupOk {
            Set tSC = $$$ERROR($$$GeneralError, "Setup could not confirm the three principals' pairs: both " _ tBoth _ ", no-operate " _ tNoOperate _ ", no-sys " _ tNoSys)
        }
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Remove the three accounts and their roles, and return a failing status if any survives.</p>
Method OnAfterAllTests() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISERR(tSC) Quit
        Set tLeft = ""
        For tUser = ..#BOTHUSER, ..#NOOPERATEUSER, ..#NOSYSUSER {
            If ##class(Security.Users).Exists(tUser, .tU, .tUS) Do ##class(Security.Users).Delete(tUser)
            If ##class(Security.Users).Exists(tUser, .tU2, .tUS2) Set tLeft = tLeft _ $Select(tLeft = "": "", 1: ", ") _ "user " _ tUser
        }
        For tRole = ..#BOTHROLE, ..#NOOPERATEROLE, ..#NOSYSROLE {
            If ##class(Security.Roles).Exists(tRole, .tR, .tRS) Do ##class(Security.Roles).Delete(tRole)
            If ##class(Security.Roles).Exists(tRole, .tR2, .tRS2) Set tLeft = tLeft _ $Select(tLeft = "": "", 1: ", ") _ "role " _ tRole
        }
        If tLeft '= "" {
            Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.UiPerformanceWire teardown left throwaway objects on the instance: " _ tLeft)
        }
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Create (or re-grant) one throwaway role and the account that holds it.
/// <b>Caller contract:</b> <code>$NAMESPACE</code> must already be <code>%SYS</code>.</p>
Method EnsurePrincipal(pRole As %String, pUser As %String, pResources As %String, pPassword As %String) As %Status
{
    Set tSC = $$$OK
    If ##class(Security.Roles).Exists(pRole, .tR, .tRS) {
        Set tModProps("Resources") = pResources
        Set tModProps("GrantedRoles") = ""
        Set tModProps("ForceSave") = 2
        Set tSC = ##class(Security.Roles).Modify(pRole, .tModProps)
    } Else {
        Set tSC = ##class(Security.Roles).Create(pRole, "OcuPilot test: performance row principal role (throwaway)", pResources, "")
    }
    If $$$ISERR(tSC) Quit tSC
    If ##class(Security.Users).Exists(pUser, .tU, .tUS) {
        Set tSC = ##class(Security.Users).Delete(pUser)
        If $$$ISERR(tSC) Quit tSC
    }
    Quit ##class(Security.Users).Create(pUser, pRole, pPassword, "OcuPilot performance row test principal (throwaway)", "", "", "", 0, 1, "Created by OcuPilot.Test.UiPerformanceWire; deleted in OnAfterAllTests")
}

/// <p>One request to the route as <var>pUser</var>. <var>pAnswer</var> is the parsed body, or
/// <code>""</code>.</p>
Method Call(pUser As %String, pPassword As %String, Output pStatus As %Integer, Output pAnswer As %DynamicObject, Output pHeaders) As %Status
{
    Set pAnswer = ""
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest(..#READVERB, ..#PERFORMANCEPATH, pUser, pPassword, .pStatus, .tBody, .pHeaders)
    If $$$ISERR(tSC) Quit tSC
    Try {
        Set pAnswer = ##class(%DynamicObject).%FromJSON($ZConvert(tBody, "I", "UTF8"))
    } Catch {
        Set pAnswer = ""
    }
    Quit tSC
}

/// <p>How many of the five members <var>pAnswer</var> carries as JSON numbers, and whether it
/// carries nothing else.</p>
ClassMethod NumberCount(pAnswer As %DynamicObject, Output pOnlyThose As %Boolean) As %Integer
{
    Set pOnlyThose = 0
    If '$IsObject(pAnswer) Quit 0
    Set tCount = 0
    For tI = 1:1:$Length(..#WIREMEMBERS, ",") {
        If pAnswer.%GetTypeOf($Piece(..#WIREMEMBERS, ",", tI)) = "number" Set tCount = tCount + 1
    }
    Set tKeys = 0
    Set tIterator = pAnswer.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        Set tKeys = tKeys + 1
    }
    Set pOnlyThose = (tKeys = $Length(..#WIREMEMBERS, ","))
    Quit tCount
}

/// <p>Matrix, Present: the suite's own account and a principal holding exactly the two pairs each
/// read the five live values as JSON numbers, and nothing else.</p>
/// <p>Mutation: drop <code>globalReferencesPerSecond</code> from
/// <parameter>OcuPilot.Port.MonitorPort.METRICS</parameter> -&gt; four numbers, and this goes red.</p>
Method TestACallerHoldingBothPairsReadsFiveNumbers()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup confirmed the principals' pairs")
    For tCase = $ListBuild(##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword()), $ListBuild(..#BOTHUSER, ..PreparedPassword) {
        Set tUser = $List(tCase, 1)
        Set tSC = ..Call(tUser, $List(tCase, 2), .tStatus, .tAnswer, .tHeaders)
        Do $$$AssertStatusOK(tSC, tUser _ ": the request completes")
        Do $$$AssertEquals(tStatus, 200, tUser _ ": the row is read")
        Do $$$AssertTrue($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", tUser _ ": as application/json")
        Do $$$AssertEquals(..NumberCount(tAnswer, .tOnly), 5, tUser _ ": carrying five numbers: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: ""))
        Do $$$AssertTrue(tOnly, tUser _ ": and nothing else")
    }
}

/// <p>Matrix, Denied: a principal lacking either pair is refused 403 <code>AUTH.NOPRIVILEGE</code>,
/// naming the pair it lacks, with no value in the body.</p>
/// <p>Mutation: drop the <code>EvaluateRequired</code> call from
/// <method>OcuPilot.Port.MonitorPort.Performance</method> -&gt; the principal without
/// <code>%Admin_Operate</code> reads 200 and the one without <code>%DB_IRISSYS</code> reads 500, and
/// both rows go red.</p>
Method TestACallerLackingEitherPairIsRefusedNamingIt()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup confirmed the principals' pairs")
    For tCase = $ListBuild(..#NOOPERATEUSER, "%Admin_Operate:USE"), $ListBuild(..#NOSYSUSER, "%DB_IRISSYS:READ") {
        Set tUser = $List(tCase, 1)
        Set tSC = ..Call(tUser, ..PreparedPassword, .tStatus, .tAnswer, .tHeaders)
        Do $$$AssertStatusOK(tSC, tUser _ ": the request completes")
        Do $$$AssertEquals(tStatus, 403, tUser _ ": the read is refused")
        Do $$$AssertTrue($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", tUser _ ": as application/json")
        Set tPair = ""
        If $IsObject(tAnswer) && $IsObject(tAnswer.%Get("detail")) Set tPair = tAnswer.detail.failedPair
        Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.code, 1: "") _ " " _ tPair, "AUTH.NOPRIVILEGE " _ $List(tCase, 2), tUser _ ": naming the pair it lacks")
        Do $$$AssertEquals(..NumberCount(tAnswer, .tOnly), 0, tUser _ ": with no value")
    }
}

}

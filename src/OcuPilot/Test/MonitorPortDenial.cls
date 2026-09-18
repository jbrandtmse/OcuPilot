/// <p>The alerts.log viewer's pair set against the <b>real</b> <code>$System.Security.Check</code>
/// (AD-8, AD-29): over the wire on both of the screen's routes and on its read tool, and at the port
/// called directly, as it is on the tool path.</p>
/// <ul>
/// <li>A principal holding read on the install namespace's code database and both declared pairs
/// reads the screen, the bounded tail and the recent entries with 200.</li>
/// <li>A principal holding <code>%Admin_Operate:USE</code> and not <code>%DB_IRISSYS:READ</code> is
/// refused 403 <code>AUTH.NOPRIVILEGE</code> naming that pair, and by
/// <method>OcuPilot.Port.MonitorPort.Invoke</method> itself <b>before any vendor call</b> -- which
/// the vendor-entry counter reading zero is what establishes (AC1).</li>
/// </ul>
/// <p>The direct call runs in a child process (<class>OcuPilot.Test.MonitorDenialProbe</class>) that
/// logs in as the principal, so this process never changes identity.</p>
/// <p><b>It creates security principals, so it runs on a throwaway container only</b>
/// (<file>scripts/ci-throwaway.sh</file>), and <method>OnBeforeAllTests</method> refuses anywhere
/// <parameter>ARMINGVARIABLE</parameter> does not arm it. Their password is generated for the run and
/// never written to source; both are deleted in <method>OnAfterAllTests</method>.</p>
Class OcuPilot.Test.MonitorPortDenial Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, and the one value that arms it:
/// <code>1</code>.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

/// <p>The principal holding both declared pairs.</p>
Parameter BOTHUSER = "OcuPilotMonitorBoth";

/// <p>See <parameter>BOTHUSER</parameter>.</p>
Parameter BOTHROLE = "OcuPilotMonitorBothRole";

/// <p>The principal holding <code>%Admin_Operate:USE</code> and not
/// <code>%DB_IRISSYS:READ</code>.</p>
Parameter NOSYSTEMUSER = "OcuPilotMonitorNoSystem";

/// <p>See <parameter>NOSYSTEMUSER</parameter>.</p>
Parameter NOSYSTEMROLE = "OcuPilotMonitorNoSystemRole";

/// <p>The screen's read tool.</p>
Parameter TOOL = "logs.alerts";

/// <p>The two accounts' password for this run, generated in <method>OnBeforeAllTests</method>.</p>
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

/// <p>Refuse to run unless this instance is armed for throwaway principals, then create the two
/// principals and read their pairs back.</p>
Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.MonitorPortDenial creates and deletes IRIS users and roles on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so no principal was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set tInstallNs = ##class(OcuPilot.Install.Installer).ResolveNamespace()
        Set ..PreparedPassword = "OcuPilotMonitor" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"

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
        Set tSC = ..EnsurePrincipal(..#NOSYSTEMROLE, ..#NOSYSTEMUSER, tCodeRead _ ",%Admin_Operate:U", ..PreparedPassword)
        If $$$ISERR(tSC) Quit

        Set tBoth = ($SYSTEM.Security.CheckUserPermission(..#BOTHUSER, "%Admin_Operate", "USE") = 1) && ($SYSTEM.Security.CheckUserPermission(..#BOTHUSER, "%DB_IRISSYS", "READ") = 1)
        Set tNoSystem = ($SYSTEM.Security.CheckUserPermission(..#NOSYSTEMUSER, "%Admin_Operate", "USE") = 1) && ($SYSTEM.Security.CheckUserPermission(..#NOSYSTEMUSER, "%DB_IRISSYS", "READ") '= 1)
        Set ..PreparedSetupOk = tBoth && tNoSystem
        If '..PreparedSetupOk {
            Set tSC = $$$ERROR($$$GeneralError, "Setup could not confirm the two principals' pairs: both " _ tBoth _ ", no-system " _ tNoSystem)
        }
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Remove the two accounts and their roles, and return a failing status if any survives.</p>
Method OnAfterAllTests() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISERR(tSC) Quit
        Set tLeft = ""
        For tUser = ..#BOTHUSER, ..#NOSYSTEMUSER {
            If ##class(Security.Users).Exists(tUser, .tU, .tUS) Do ##class(Security.Users).Delete(tUser)
            If ##class(Security.Users).Exists(tUser, .tU2, .tUS2) Set tLeft = tLeft _ $Select(tLeft = "": "", 1: ", ") _ "user " _ tUser
        }
        For tRole = ..#BOTHROLE, ..#NOSYSTEMROLE {
            If ##class(Security.Roles).Exists(tRole, .tR, .tRS) Do ##class(Security.Roles).Delete(tRole)
            If ##class(Security.Roles).Exists(tRole, .tR2, .tRS2) Set tLeft = tLeft _ $Select(tLeft = "": "", 1: ", ") _ "role " _ tRole
        }
        If tLeft '= "" {
            Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.MonitorPortDenial teardown left throwaway objects on the instance: " _ tLeft)
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
        Set tSC = ##class(Security.Roles).Create(pRole, "OcuPilot test: monitoring API principal role (throwaway)", pResources, "")
    }
    If $$$ISERR(tSC) Quit tSC
    If ##class(Security.Users).Exists(pUser, .tU, .tUS) {
        Set tSC = ##class(Security.Users).Delete(pUser)
        If $$$ISERR(tSC) Quit tSC
    }
    Quit ##class(Security.Users).Create(pUser, pRole, pPassword, "OcuPilot monitoring API test principal (throwaway)", "", "", "", 0, 1, "Created by OcuPilot.Test.MonitorPortDenial; deleted in OnAfterAllTests")
}

/// <p>Request <var>pPath</var> as <var>pUser</var>. <var>pAnswer</var> is the parsed body, or
/// <code>""</code>, and <var>pHeaders</var> the response headers.</p>
Method Get(pUser As %String, pPath As %String, Output pStatus As %Integer, Output pAnswer As %DynamicObject, Output pHeaders) As %Status
{
    Set pAnswer = ""
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", pPath, pUser, ..PreparedPassword, .pStatus, .tBody, .pHeaders)
    If $$$ISERR(tSC) Quit tSC
    Try {
        Set pAnswer = ##class(%DynamicObject).%FromJSON($ZConvert(tBody, "I", "UTF8"))
    } Catch {
        Set pAnswer = ""
    }
    Quit tSC
}

/// <p>A probe leg as <code>http calls code failedPair</code>, for one-line comparisons; a leg that
/// counted no vendor calls leaves the count out.</p>
ClassMethod LegText(pProbe As %DynamicObject, pLeg As %String) As %String
{
    Set tLeg = pProbe.%Get(pLeg)
    If '$IsObject(tLeg) Quit "absent"
    Set tFault = tLeg.%Get("fault")
    Set tCode = ""
    Set tPair = ""
    If $IsObject(tFault) {
        Set tCode = tFault.%Get("code")
        If $IsObject(tFault.%Get("detail")) Set tPair = tFault.detail.%Get("failedPair")
    }
    Quit tLeg.http _ $Select(tLeg.%IsDefined("calls"): " calls=" _ tLeg.calls, 1: "") _ " " _ tCode _ " " _ tPair
}

/// <p>AC9 -- a principal holding exactly the two declared pairs, and never <code>%Operator</code>,
/// reads the screen, the bounded tail and the recent entries. If the instance still refuses one of
/// them, the declared set is a lower bound that needs widening (AD-29), and this is where that shows
/// as a failure rather than as a 500 naming no pair.</p>
Method TestAPrincipalHoldingTheDeclaredPairsReadsEveryRoute()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup confirmed the principals' pairs")

    Set tSC = ..Get(..#BOTHUSER, "/api/ocupilot/screens/" _ ..#TOOL _ "/read?maxRows=5", .tStatus, .tAnswer, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the screen read completes")
    Do $$$AssertEquals(tStatus, 200, "the declared read answers: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: ""))
    Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "application/json", "as application/json")
    Do $$$AssertTrue($IsObject(tAnswer) && $IsObject(tAnswer.%Get("rows")), "with a rows array")

    Set tSC = ..Get(..#BOTHUSER, "/api/ocupilot/logs/alerts?maxBytes=4096", .tStatus, .tAnswer, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the tail request completes")
    Do $$$AssertEquals(tStatus, 200, "the bounded tail answers: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: ""))
    Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "application/json", "as application/json")
    Do $$$AssertTrue($IsObject(tAnswer) && $IsObject(tAnswer.%Get("lines")), "with a lines array")

    Set tSC = ..Get(..#BOTHUSER, "/api/ocupilot/logs/alerts/recent", .tStatus, .tAnswer, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the recent request completes")
    Do $$$AssertEquals(tStatus, 200, "the recent entries answer: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: ""))
    Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "application/json", "as application/json")
    Do $$$AssertTrue($IsObject(tAnswer) && $IsObject(tAnswer.%Get("rows")), "with a rows array and the tag to page from")
    Do $$$AssertTrue($IsObject(tAnswer) && tAnswer.%IsDefined("tag"), "and the cursor for the next call")

    Set tProbe = ..ProbeAs(..#BOTHUSER)
    Do $$$AssertEquals(tProbe.%Get("error"), "", "the probe ran: " _ tProbe.%ToJSON())
    Do $$$AssertEquals(tProbe.%Get("username"), ..#BOTHUSER, "as the principal")
    Do $$$AssertEquals(..LegText(tProbe, "Alerts"), "200 calls=1  ", "a direct call reaches the vendor")
    Do $$$AssertEquals(..LegText(tProbe, "Port"), "200  ", "and the production port answers the live instance's alerts")
}

/// <p>AC1 and AC9 -- a principal without <code>%DB_IRISSYS:READ</code> is refused 403
/// <code>AUTH.NOPRIVILEGE</code> naming that pair on every route, and by the port called directly
/// <b>with the vendor-entry counter at zero</b>: the refusal precedes argument reading and vendor
/// code alike.</p>
/// <p>Mutation: move the <code>PAIRS</code> evaluation in
/// <method>OcuPilot.Port.MonitorPort.Invoke</method> to after the vendor call -&gt; the counter reads
/// 1 and this reddens. Remove <code>%DB_IRISSYS:READ</code> from <code>PAIRS</code> -&gt; the named
/// pair is no longer that one and this reddens.</p>
Method TestAPrincipalWithoutTheSystemDatabaseReadIsRefusedNamingThatPair()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup confirmed the principals' pairs")

    Set tSC = ..Get(..#NOSYSTEMUSER, "/api/ocupilot/screens/" _ ..#TOOL _ "/read?maxRows=5", .tStatus, .tAnswer, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the screen read completes")
    Do $$$AssertEquals(tStatus, 403, "the route refuses")
    Set tPair = ""
    If $IsObject(tAnswer) && $IsObject(tAnswer.%Get("detail")) Set tPair = tAnswer.detail.failedPair
    Do $$$AssertEquals(tPair, "%DB_IRISSYS:READ", "naming the pair this principal does not hold: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: ""))

    Set tSC = ..Get(..#NOSYSTEMUSER, "/api/ocupilot/logs/alerts/recent", .tStatus, .tAnswer, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the recent request completes")
    Do $$$AssertEquals(tStatus, 403, "the recent route refuses")
    Set tPair = ""
    If $IsObject(tAnswer) && $IsObject(tAnswer.%Get("detail")) Set tPair = tAnswer.detail.failedPair
    Do $$$AssertEquals(tPair, "%DB_IRISSYS:READ", "naming the same pair")

    ; The bounded tail declares %Admin_Operate:USE alone -- reading a file off disk consults no
    ; database resource -- so this principal reads it. That is the pair sets differing on purpose,
    ; and asserting it here is what keeps the tail's set from being widened to match the screen's.
    Set tSC = ..Get(..#NOSYSTEMUSER, "/api/ocupilot/logs/alerts?maxBytes=4096", .tStatus, .tAnswer, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the tail request completes")
    Do $$$AssertEquals(tStatus, 200, "and the bounded tail still answers, needing only %Admin_Operate:USE")

    Set tProbe = ..ProbeAs(..#NOSYSTEMUSER)
    Do $$$AssertEquals(tProbe.%Get("error"), "", "the probe ran: " _ tProbe.%ToJSON())
    Do $$$AssertEquals(tProbe.%Get("loggedIn"), 1, "the probe logged in")
    Do $$$AssertEquals(tProbe.%Get("username"), ..#NOSYSTEMUSER, "as the principal")
    Do $$$AssertEquals(..LegText(tProbe, "Alerts"), "403 calls=0 AUTH.NOPRIVILEGE %DB_IRISSYS:READ", "a direct call is refused by the port naming the pair, with no vendor call")
    Do $$$AssertEquals(..LegText(tProbe, "Port"), "403 AUTH.NOPRIVILEGE %DB_IRISSYS:READ", "and so is a call to the production port itself")
}

/// <p>Run <class>OcuPilot.Test.MonitorDenialProbe</class> as <var>pUser</var> in a child process and
/// answer what it signalled, or an object carrying <code>error</code>.</p>
ClassMethod ProbeAs(pUser As %String) As %DynamicObject
{
    Set tOut = {}
    Try {
        Do $System.Event.Clear($Job)
        Job ##class(OcuPilot.Test.MonitorDenialProbe).Run($Job, pUser)::10
        If '$Test {
            Do tOut.%Set("error", "the probe process did not start")
            Quit
        }
        Set tMessage = $System.Event.WaitMsg("", 60)
        If $ListGet(tMessage, 1) '= 1 {
            Do tOut.%Set("error", "the probe process signalled nothing within 60 seconds")
            Quit
        }
        Set tOut = ##class(%DynamicObject).%FromJSON($ListGet(tMessage, 2))
    } Catch ex {
        Set tOut = {}
        Do tOut.%Set("error", ex.DisplayString())
    }
    Quit tOut
}

}

/// <p>The console-log page's pair set over the wire, against the <b>real</b>
/// <code>$System.Security.Check</code> (AD-8, AD-29, DW-278). A principal holding
/// <code>%Admin_Secure:USE</code> -- which clears the API's own administrative gate -- and not
/// <code>%Admin_Operate:USE</code> is refused 403 naming the pair it lacks; a principal holding
/// <code>%Admin_Operate:USE</code> and <b>neither</b> <code>%Admin_Secure:USE</code> <b>nor</b>
/// <code>%DB_IRISSYS:READ</code> is served.</p>
/// <p>That second leg is the measurement DW-278's recommendation rests on: it establishes on a
/// real principal that one pair is the whole requirement for this source, so the two the Logs
/// <i>area</i> also declares are surplus to it rather than assumed to be.</p>
/// <p><b>Two purpose-built principals, created in <method>OnBeforeAllTests</method> and deleted in
/// <method>OnAfterAllTests</method>.</b> Each holds read on the install namespace's code database,
/// without which IRIS cannot load the dispatch class for that request at all. Their password is
/// generated for the run and never written to source.</p>
/// <p><b>It creates security principals, so it runs on a throwaway container only</b>
/// (<file>scripts/ci-throwaway.sh</file>, <code>ocupilot-ci</code>), and
/// <method>OnBeforeAllTests</method> refuses anywhere <parameter>ARMINGVARIABLE</parameter> does
/// not arm it. Needs the API application installed and a readable <file>messages.log</file>; it
/// reads that file and never writes, rotates or removes it.</p>
Class OcuPilot.Test.LogSourceDenial Extends %UnitTest.TestCase
{

/// <p>The console-log route.</p>
Parameter LOGPATH = "/api/ocupilot/logs/messages";

/// <p>The alert-log route (Story 6.13), which declares the same one pair as the console log.</p>
Parameter ALERTPATH = "/api/ocupilot/logs/alerts";

/// <p>The alerts.log screen's own declared read, reached generically. It runs the same source key
/// through <method>OcuPilot.Port.LogSourcePort.Rows</method>, so it is the second way in to the
/// same file and has to meet the same gate.</p>
Parameter ALERTREADPATH = "/api/ocupilot/screens/logs.alerts/read";

/// <p>The environment variable that arms this class, and the one value that arms it:
/// <code>1</code>. Only <file>scripts/ci-throwaway.sh</file> sets it, so the principals are
/// created on the container that script builds and nowhere else. Anything else -- absent, empty,
/// or a value that reads like a refusal such as <code>0</code> -- refuses.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

/// <p>The principal holding <code>%Admin_Secure:U</code> and not
/// <code>%Admin_Operate:U</code> -- the denied one. It clears the API's administrative gate, so
/// what refuses it is the port's own.</p>
Parameter SECUREUSER = "OcuPilotLogSecure";

/// <p>See <parameter>SECUREUSER</parameter>.</p>
Parameter SECUREROLE = "OcuPilotLogSecureRole";

/// <p>The principal holding <code>%Admin_Operate:U</code> and neither
/// <code>%Admin_Secure:U</code> nor <code>%DB_IRISSYS:R</code> -- the allowed one, and the
/// DW-278 measurement.</p>
Parameter OPERATEUSER = "OcuPilotLogOperate";

/// <p>See <parameter>OPERATEUSER</parameter>.</p>
Parameter OPERATEROLE = "OcuPilotLogOperateRole";

/// <p>The two accounts' password for this run, generated in <method>OnBeforeAllTests</method> and
/// never written to source.</p>
Property PreparedPassword As %String;

/// <p>Whether <method>OnBeforeAllTests</method> read back, through
/// <code>$SYSTEM.Security.CheckUserPermission</code>, that each account holds exactly the pairs it
/// is meant to and none of the ones it is meant to lack.</p>
Property PreparedSetupOk As %Boolean [ InitialExpression = 0 ];

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPassword = ""
    Set ..PreparedSetupOk = 0
    Quit $$$OK
}

/// <p>Refuse to run at all unless this instance is armed for throwaway principals.</p>
/// <p><b>A doc comment does not keep a destructive class off a development instance.</b> Test
/// classes are selected by package -- <file>ui/tools/ci-runner.mjs</file> runs every
/// <class>%UnitTest.TestCase</class> the instance offers under <code>OcuPilot.Test</code> -- so
/// pointing the runner at a container someone cares about would create two accounts and two roles
/// on it, and <method>EnsurePrincipal</method> deletes any account already holding one of those
/// names before it creates its own. Failing here is the honest outcome: nothing is created and
/// the reason is named.</p>
Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.LogSourceDenial creates and deletes IRIS users and roles on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so no principal was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set tInstallNs = ##class(OcuPilot.Install.Installer).ResolveNamespace()
        Set ..PreparedPassword = "OcuPilotLog" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"

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

        Set tSC = ..EnsurePrincipal(..#SECUREROLE, ..#SECUREUSER, tCodeRead _ ",%Admin_Secure:U", ..PreparedPassword)
        If $$$ISERR(tSC) Quit
        Set tSC = ..EnsurePrincipal(..#OPERATEROLE, ..#OPERATEUSER, tCodeRead _ ",%Admin_Operate:U", ..PreparedPassword)
        If $$$ISERR(tSC) Quit

        Set tSecure = ($SYSTEM.Security.CheckUserPermission(..#SECUREUSER, "%Admin_Secure", "USE") = 1) && ($SYSTEM.Security.CheckUserPermission(..#SECUREUSER, "%Admin_Operate", "USE") '= 1)
        ; The allowed principal holds the one pair and NEITHER of the two the Logs area also
        ; declares. Reading both back is what makes the DW-278 measurement a measurement.
        Set tOperate = ($SYSTEM.Security.CheckUserPermission(..#OPERATEUSER, "%Admin_Operate", "USE") = 1) && ($SYSTEM.Security.CheckUserPermission(..#OPERATEUSER, "%Admin_Secure", "USE") '= 1) && ($SYSTEM.Security.CheckUserPermission(..#OPERATEUSER, "%DB_IRISSYS", "READ") '= 1)
        Set ..PreparedSetupOk = tSecure && tOperate
        If '..PreparedSetupOk {
            Set tSC = $$$ERROR($$$GeneralError, "Setup could not confirm the two principals' pairs: secure " _ tSecure _ ", operate " _ tOperate)
        }
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Remove the two accounts and their roles, and <b>return a failing status</b> if any survives.
/// Reported through the status rather than assertions, which <code>%UnitTest.Manager</code> does
/// not record from this method.</p>
Method OnAfterAllTests() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISERR(tSC) Quit
        Set tLeft = ""
        For tUser = ..#SECUREUSER, ..#OPERATEUSER {
            If ##class(Security.Users).Exists(tUser, .tU, .tUS) Do ##class(Security.Users).Delete(tUser)
            If ##class(Security.Users).Exists(tUser, .tU2, .tUS2) Set tLeft = tLeft _ $Select(tLeft = "": "", 1: ", ") _ "user " _ tUser
        }
        For tRole = ..#SECUREROLE, ..#OPERATEROLE {
            If ##class(Security.Roles).Exists(tRole, .tR, .tRS) Do ##class(Security.Roles).Delete(tRole)
            If ##class(Security.Roles).Exists(tRole, .tR2, .tRS2) Set tLeft = tLeft _ $Select(tLeft = "": "", 1: ", ") _ "role " _ tRole
        }
        If tLeft '= "" {
            Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.LogSourceDenial teardown left throwaway objects on the instance: " _ tLeft)
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
        Set tSC = ##class(Security.Roles).Create(pRole, "OcuPilot test: log source principal role (throwaway)", pResources, "")
    }
    If $$$ISERR(tSC) Quit tSC
    If ##class(Security.Users).Exists(pUser, .tU, .tUS) {
        Set tSC = ##class(Security.Users).Delete(pUser)
        If $$$ISERR(tSC) Quit tSC
    }
    Quit ##class(Security.Users).Create(pUser, pRole, pPassword, "OcuPilot log source test principal (throwaway)", "", "", "", 0, 1, "Created by OcuPilot.Test.LogSourceDenial; deleted in OnAfterAllTests")
}

/// <p>Request the console-log page as <var>pUser</var>.</p>
Method Fetch(pUser As %String, pQuery As %String, Output pStatus As %Integer, Output pBody As %String, Output pHeaders) As %Status
{
    Set tPath = ..#LOGPATH
    If pQuery '= "" Set tPath = tPath _ "?" _ pQuery
    Quit ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tPath, pUser, ..PreparedPassword, .pStatus, .pBody, .pHeaders)
}

/// <p>AC4 -- a principal the API's own administrative gate admits, and the port's pair set does
/// not, is refused 403 <code>AUTH.NOPRIVILEGE</code> with <code>%Admin_Operate:USE</code> named as
/// the pair that failed.</p>
/// <p><b>Why it has to be a real principal.</b> <code>%All</code> passes every resource check, so
/// the suite's own account could never observe this; and <code>%Admin_Secure:USE</code> is what
/// makes the refusal the <i>port's</i> rather than the router's, which would answer
/// <code>AUTH.NOADMIN</code> to a principal holding no administrative resource at all.</p>
/// <p>Mutation: make <method>OcuPilot.Port.LogSourcePort.Gate</method> answer 1 unconditionally
/// -&gt; the page is served and the status, code and failed-pair assertions go red.</p>
Method TestAPrincipalWithoutAdminOperateIsRefused()
{
    Set tSC = ..Fetch(..#SECUREUSER, "maxBytes=4096", .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(tStatus, 403, "the read is refused")
    Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "application/json", "as application/json")
    Do $$$AssertEquals((tBody [ "}{"), 0, "exactly one envelope")
    Set tFault = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tFault.code, "AUTH.NOPRIVILEGE", "on the screen-privilege code, not the router's AUTH.NOADMIN")
    Do $$$AssertEquals($Select($IsObject(tFault.detail): tFault.detail.failedPair, 1: ""), "%Admin_Operate:USE", "naming the pair that failed")
    Do $$$AssertEquals(tFault.%IsDefined("lines"), 0, "and no page comes back with it")
}

/// <p>AC4 (DW-278) -- a principal holding <code>%Admin_Operate:USE</code> and <b>neither</b>
/// <code>%Admin_Secure:USE</code> <b>nor</b> <code>%DB_IRISSYS:READ</code> is served the page.
/// That one pair is the whole requirement for this source, measured rather than asserted: the
/// other two the Logs area declares are what DW-278's false denial is about, and this leg is the
/// evidence that they are surplus <i>here</i>.</p>
/// <p>Mutation: add <code>%DB_IRISSYS:READ</code> to
/// <parameter>OcuPilot.Port.LogSourcePort.MESSAGESPAIRS</parameter> -&gt; this principal is
/// refused and every assertion here goes red, while
/// <method>TestAPrincipalWithoutAdminOperateIsRefused</method> stays green.</p>
Method TestAdminOperateAloneIsServed()
{
    Set tSC = ..Fetch(..#OPERATEUSER, "maxBytes=4096", .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(tStatus, 200, "the page is served to a principal holding only %Admin_Operate:USE")
    Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "application/json", "as application/json")
    Do $$$AssertEquals((tBody [ "}{"), 0, "exactly one envelope")
    If tStatus '= 200 Quit
    Set tPage = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tPage.source, "messages", "the source the route bound")
    Do $$$AssertTrue(tPage.lines.%Size() > 0, "and the log's lines come back: " _ tPage.lines.%Size())
    Do $$$AssertEquals(tPage.%GetTypeOf("restarted"), "boolean", "with the page contract intact")
}

/// <p>Request <var>pPath</var> as <var>pUser</var>.</p>
Method FetchPath(pUser As %String, pPath As %String, Output pStatus As %Integer, Output pBody As %String, Output pHeaders) As %Status
{
    Quit ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", pPath, pUser, ..PreparedPassword, .pStatus, .pBody, .pHeaders)
}

/// <p>Story 6.13 AC9 -- the alert log's declared pair set, measured on a purpose-built principal
/// rather than copied from the console log's. <b>Both ways in meet the same gate</b>: the bounded
/// tail the screen pages by and the declared read the agent tool derives from. A principal holding
/// <code>%Admin_Operate:USE</code> alone is served both; one holding <code>%Admin_Secure:USE</code>
/// and not <code>%Admin_Operate:USE</code> is refused both, on the port's own code and with the
/// pair named.</p>
/// <p>Needs nothing of the instance's own <file>alerts.log</file>: an instance that has raised no
/// alert has no such file, and the port names that absence <b>after</b> the gate, so reaching
/// <code>LOG.ABSENT</code> is itself evidence the gate admitted the caller.</p>
/// <p>Mutation: add <code>%DB_IRISSYS:READ</code> to
/// <parameter>OcuPilot.Port.LogSourcePort.ALERTSPAIRS</parameter> -&gt; the operate-only principal
/// is refused 403 and the two served assertions go red.</p>
Method TestTheAlertLogsOnePairGovernsBothWaysIn()
{
    Set tSC = ..FetchPath(..#SECUREUSER, ..#ALERTPATH _ "?maxBytes=4096", .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the refused tail request completes")
    Do $$$AssertEquals(tStatus, 403, "the tail is refused to a principal without %Admin_Operate:USE")
    Set tFault = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tFault.code, "AUTH.NOPRIVILEGE", "on the screen-privilege code")
    Do $$$AssertEquals($Select($IsObject(tFault.detail): tFault.detail.failedPair, 1: ""), "%Admin_Operate:USE", "naming the pair that failed")

    Set tSC = ..FetchPath(..#SECUREUSER, ..#ALERTREADPATH _ "?maxRows=5", .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the refused declared-read request completes")
    Do $$$AssertEquals(tStatus, 403, "and so is the declared read")
    Set tReadFault = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tReadFault.code, "AUTH.NOPRIVILEGE", "on the same code")
    Do $$$AssertEquals($Select($IsObject(tReadFault.detail): tReadFault.detail.failedPair, 1: ""), "%Admin_Operate:USE", "naming the same pair")

    Set tSC = ..FetchPath(..#OPERATEUSER, ..#ALERTPATH _ "?maxBytes=4096", .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the served tail request completes")
    Do $$$AssertTrue((tStatus = 200) || (tStatus = 404), "%Admin_Operate:USE alone carries the tail past the gate: " _ tStatus)
    If tStatus = 200 {
        Set tPage = ##class(%DynamicObject).%FromJSON(tBody)
        Do $$$AssertEquals(tPage.source, "alerts", "the source the route bound")
    } Else {
        Set tAbsent = ##class(%DynamicObject).%FromJSON(tBody)
        Do $$$AssertEquals(tAbsent.code, "LOG.ABSENT", "and on an instance that has raised no alert the refusal is the file's absence, which is past the gate")
    }

    Set tSC = ..FetchPath(..#OPERATEUSER, ..#ALERTREADPATH _ "?maxRows=5", .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the served declared-read request completes")
    Do $$$AssertEquals(tStatus, 200, "and for the declared read the tool derives from")
    If tStatus = 200 {
        Set tRead = ##class(%DynamicObject).%FromJSON(tBody)
        Do $$$AssertEquals(tRead.fields.%ToJSON(), "[""time"",""severity"",""text""]", "which answers the declared fields")
    }
}

}

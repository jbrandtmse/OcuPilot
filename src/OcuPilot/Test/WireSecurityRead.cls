/// <p>The admin-port reads' privilege pair sets over the wire, against the <b>real</b>
/// <code>$System.Security.Check</code> (AD-8, DW-262, DW-264). Every one of them needs
/// <code>%DB_IRISSYS:READ</code>, because the port runs every endpoint in <code>%SYS</code>, plus
/// its own administrative resource: <code>%Admin_Secure:USE</code> for the users, web applications
/// and SSL/TLS configurations lists, <code>%Admin_Task:USE</code> for the task schedule, and
/// <code>%Admin_Operate:USE</code> plus <code>%Admin_Manage:USE</code> for the processes list. A
/// principal holding some of a screen's pairs is denied on the first one it does not hold, in the
/// navigation map, for the screen and for its area, and on the read route.</p>
/// <p><b>Seven purpose-built principals, created in <method>OnBeforeAllTests</method> and deleted in
/// <method>OnAfterAllTests</method></b>, the shape <class>OcuPilot.Test.Wire</class> builds. Each holds
/// read on the install namespace's code database. <parameter>SECUREUSER</parameter> adds
/// <code>%Admin_Secure:U</code>; <parameter>SYSREADUSER</parameter> adds <code>%DB_IRISSYS:R</code>
/// and <code>%Admin_Operate:U</code>, the second because the API's administrative gate refuses a
/// caller holding no <code>%Admin_*</code> resource before any screen gate runs;
/// <parameter>BOTHUSER</parameter> adds <code>%Admin_Secure:U</code> and <code>%DB_IRISSYS:R</code>;
/// <parameter>TASKUSER</parameter> adds <code>%Admin_Task:U</code> alone,
/// <parameter>TASKBOTHUSER</parameter> adds <code>%Admin_Task:U</code> and
/// <code>%DB_IRISSYS:R</code>, <parameter>OPERATEUSER</parameter> adds
/// <code>%Admin_Operate:U</code> and <code>%DB_IRISSYS:R</code>, and
/// <parameter>PROCESSUSER</parameter> adds those two plus <code>%Admin_Manage:U</code>. Each screen
/// gets its own accounts rather than widening an earlier one's, so every existing leg still
/// exercises the account it names.
/// <b>It creates security principals, so it runs on a throwaway container only.</b></p>
/// <p>Needs the API application installed and at least one SSL/TLS configuration on the instance,
/// which <method>TestBothPairsReadEveryList</method> asserts rows for.</p>
Class OcuPilot.Test.WireSecurityRead Extends %UnitTest.TestCase
{

/// <p>The principal holding <code>%Admin_Secure:U</code> and not <code>%DB_IRISSYS:R</code>.</p>
Parameter SECUREUSER = "OcuPilotWireSecure";

/// <p>See <parameter>SECUREUSER</parameter>.</p>
Parameter SECUREROLE = "OcuPilotWireSecureRole";

/// <p>The principal holding <code>%DB_IRISSYS:R</code> and not <code>%Admin_Secure:U</code>.</p>
Parameter SYSREADUSER = "OcuPilotWireSysRead";

/// <p>See <parameter>SYSREADUSER</parameter>.</p>
Parameter SYSREADROLE = "OcuPilotWireSysReadRole";

/// <p>The principal holding both.</p>
Parameter BOTHUSER = "OcuPilotWireBoth";

/// <p>See <parameter>BOTHUSER</parameter>.</p>
Parameter BOTHROLE = "OcuPilotWireBothRole";

/// <p>The principal holding <code>%Admin_Task:U</code> and not <code>%DB_IRISSYS:R</code>.</p>
Parameter TASKUSER = "OcuPilotWireTask";

/// <p>See <parameter>TASKUSER</parameter>.</p>
Parameter TASKROLE = "OcuPilotWireTaskRole";

/// <p>The principal holding <code>%Admin_Task:U</code> and <code>%DB_IRISSYS:R</code>.</p>
Parameter TASKBOTHUSER = "OcuPilotWireTaskBoth";

/// <p>See <parameter>TASKBOTHUSER</parameter>.</p>
Parameter TASKBOTHROLE = "OcuPilotWireTaskBothRole";

/// <p>The principal holding <code>%Admin_Operate:U</code> and <code>%DB_IRISSYS:R</code> and not
/// <code>%Admin_Manage:U</code> -- the processes list's denied principal, and the one that shows the
/// middle pair is load-bearing rather than decorative.</p>
Parameter OPERATEUSER = "OcuPilotWireOperate";

/// <p>See <parameter>OPERATEUSER</parameter>.</p>
Parameter OPERATEROLE = "OcuPilotWireOperateRole";

/// <p>The principal holding all three of the processes list's pairs -- its allowed principal.
/// <code>%Admin_Manage:U</code> is granted to a purpose-built throwaway role on a throwaway
/// container and deleted in <method>OnAfterAllTests</method>; it is the narrower half of the
/// vendor query's own OR, the wider half being write on the IRISSYS database, which the
/// Consistency Conventions call a self-escalation primitive.</p>
Parameter PROCESSUSER = "OcuPilotWireProcess";

/// <p>See <parameter>PROCESSUSER</parameter>.</p>
Parameter PROCESSROLE = "OcuPilotWireProcessRole";

/// <p>The seven accounts' password for this run, generated in <method>OnBeforeAllTests</method> and
/// never written to source.</p>
Property PreparedPassword As %String;

/// <p>Whether <method>OnBeforeAllTests</method> read back, through
/// <code>$SYSTEM.Security.CheckUserPermission</code>, that each account holds exactly the pairs it
/// is meant to.</p>
Property PreparedSetupOk As %Boolean [ InitialExpression = 0 ];

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPassword = ""
    Set ..PreparedSetupOk = 0
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set tInstallNs = ##class(OcuPilot.Install.Installer).ResolveNamespace()
        Set ..PreparedPassword = "OcuPilotSec" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"

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
        Set tSC = ..EnsurePrincipal(..#SYSREADROLE, ..#SYSREADUSER, tCodeRead _ ",%DB_IRISSYS:R,%Admin_Operate:U", ..PreparedPassword)
        If $$$ISERR(tSC) Quit
        Set tSC = ..EnsurePrincipal(..#BOTHROLE, ..#BOTHUSER, tCodeRead _ ",%Admin_Secure:U,%DB_IRISSYS:R", ..PreparedPassword)
        If $$$ISERR(tSC) Quit
        Set tSC = ..EnsurePrincipal(..#TASKROLE, ..#TASKUSER, tCodeRead _ ",%Admin_Task:U", ..PreparedPassword)
        If $$$ISERR(tSC) Quit
        Set tSC = ..EnsurePrincipal(..#TASKBOTHROLE, ..#TASKBOTHUSER, tCodeRead _ ",%Admin_Task:U,%DB_IRISSYS:R", ..PreparedPassword)
        If $$$ISERR(tSC) Quit
        Set tSC = ..EnsurePrincipal(..#OPERATEROLE, ..#OPERATEUSER, tCodeRead _ ",%Admin_Operate:U,%DB_IRISSYS:R", ..PreparedPassword)
        If $$$ISERR(tSC) Quit
        Set tSC = ..EnsurePrincipal(..#PROCESSROLE, ..#PROCESSUSER, tCodeRead _ ",%Admin_Operate:U,%Admin_Manage:U,%DB_IRISSYS:R", ..PreparedPassword)
        If $$$ISERR(tSC) Quit

        Set tSecure = ($SYSTEM.Security.CheckUserPermission(..#SECUREUSER, "%Admin_Secure", "USE") = 1) && ($SYSTEM.Security.CheckUserPermission(..#SECUREUSER, "%DB_IRISSYS", "READ") '= 1)
        Set tSysRead = ($SYSTEM.Security.CheckUserPermission(..#SYSREADUSER, "%Admin_Secure", "USE") '= 1) && ($SYSTEM.Security.CheckUserPermission(..#SYSREADUSER, "%DB_IRISSYS", "READ") = 1)
        Set tBoth = ($SYSTEM.Security.CheckUserPermission(..#BOTHUSER, "%Admin_Secure", "USE") = 1) && ($SYSTEM.Security.CheckUserPermission(..#BOTHUSER, "%DB_IRISSYS", "READ") = 1)
        Set tTask = ($SYSTEM.Security.CheckUserPermission(..#TASKUSER, "%Admin_Task", "USE") = 1) && ($SYSTEM.Security.CheckUserPermission(..#TASKUSER, "%DB_IRISSYS", "READ") '= 1)
        Set tTaskBoth = ($SYSTEM.Security.CheckUserPermission(..#TASKBOTHUSER, "%Admin_Task", "USE") = 1) && ($SYSTEM.Security.CheckUserPermission(..#TASKBOTHUSER, "%DB_IRISSYS", "READ") = 1)
        Set tOperate = ($SYSTEM.Security.CheckUserPermission(..#OPERATEUSER, "%Admin_Operate", "USE") = 1) && ($SYSTEM.Security.CheckUserPermission(..#OPERATEUSER, "%DB_IRISSYS", "READ") = 1) && ($SYSTEM.Security.CheckUserPermission(..#OPERATEUSER, "%Admin_Manage", "USE") '= 1)
        Set tProcess = ($SYSTEM.Security.CheckUserPermission(..#PROCESSUSER, "%Admin_Operate", "USE") = 1) && ($SYSTEM.Security.CheckUserPermission(..#PROCESSUSER, "%Admin_Manage", "USE") = 1) && ($SYSTEM.Security.CheckUserPermission(..#PROCESSUSER, "%DB_IRISSYS", "READ") = 1)
        ; SECUREUSER is also the processes list's pair-ORDER principal, so the fact that it holds
        ; neither of that screen's administrative resources is read back rather than assumed.
        Set tSecureNoOperate = ($SYSTEM.Security.CheckUserPermission(..#SECUREUSER, "%Admin_Operate", "USE") '= 1) && ($SYSTEM.Security.CheckUserPermission(..#SECUREUSER, "%Admin_Manage", "USE") '= 1)
        Set ..PreparedSetupOk = tSecure && tSysRead && tBoth && tTask && tTaskBoth && tOperate && tProcess && tSecureNoOperate
        If '..PreparedSetupOk {
            Set tSC = $$$ERROR($$$GeneralError, "Setup could not confirm the seven principals' pairs: secure " _ tSecure _ ", sysread " _ tSysRead _ ", both " _ tBoth _ ", task " _ tTask _ ", taskboth " _ tTaskBoth _ ", operate " _ tOperate _ ", process " _ tProcess _ ", secure-no-operate " _ tSecureNoOperate)
        }
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Remove the seven accounts and their roles, and <b>return a failing status</b> if any survives.
/// Reported through the status rather than assertions, which <code>%UnitTest.Manager</code> does not
/// record from this method (see <method>OcuPilot.Test.Wire.OnAfterAllTests</method>).</p>
Method OnAfterAllTests() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISERR(tSC) Quit
        Set tLeft = ""
        For tUser = ..#SECUREUSER, ..#SYSREADUSER, ..#BOTHUSER, ..#TASKUSER, ..#TASKBOTHUSER, ..#OPERATEUSER, ..#PROCESSUSER {
            If ##class(Security.Users).Exists(tUser, .tU, .tUS) Do ##class(Security.Users).Delete(tUser)
            If ##class(Security.Users).Exists(tUser, .tU2, .tUS2) Set tLeft = tLeft _ $Select(tLeft = "": "", 1: ", ") _ "user " _ tUser
        }
        For tRole = ..#SECUREROLE, ..#SYSREADROLE, ..#BOTHROLE, ..#TASKROLE, ..#TASKBOTHROLE, ..#OPERATEROLE, ..#PROCESSROLE {
            If ##class(Security.Roles).Exists(tRole, .tR, .tRS) Do ##class(Security.Roles).Delete(tRole)
            If ##class(Security.Roles).Exists(tRole, .tR2, .tRS2) Set tLeft = tLeft _ $Select(tLeft = "": "", 1: ", ") _ "role " _ tRole
        }
        If tLeft '= "" {
            Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.WireSecurityRead teardown left throwaway objects on the instance: " _ tLeft)
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
        Set tSC = ##class(Security.Roles).Create(pRole, "OcuPilot test: security read principal role (throwaway)", pResources, "")
    }
    If $$$ISERR(tSC) Quit tSC
    If ##class(Security.Users).Exists(pUser, .tU, .tUS) {
        Set tSC = ##class(Security.Users).Delete(pUser)
        If $$$ISERR(tSC) Quit tSC
    }
    Quit ##class(Security.Users).Create(pUser, pRole, pPassword, "OcuPilot security read test principal (throwaway)", "", "", "", 0, 1, "Created by OcuPilot.Test.WireSecurityRead; deleted in OnAfterAllTests")
}

/// <p>The <var>pArea</var> entry's screens in the navigation map <var>pUser</var> is served, as JSON,
/// or <code>""</code> when the map does not answer.</p>
Method ScreensFor(pUser As %String, pArea As %String) As %String
{
    Set tScreens = ""
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", "/api/ocupilot/navigation", pUser, ..PreparedPassword, .tStatus, .tBody, .tHeaders)
    If $$$ISERR(tSC) || (tStatus '= 200) Quit ""
    Set tIterator = ##class(%DynamicObject).%FromJSON(tBody).areas.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tArea) {
        If tArea.key = pArea Set tScreens = tArea.screens.%ToJSON()
    }
    Quit tScreens
}

/// <p>The <var>pArea</var> entry's own verdict in the navigation map <var>pUser</var> is served, as
/// <code>allowed</code> alone or <code>allowed:failedPair</code>, or <code>""</code> when the map
/// does not answer.</p>
Method AreaVerdictFor(pUser As %String, pArea As %String) As %String
{
    Set tVerdict = ""
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", "/api/ocupilot/navigation", pUser, ..PreparedPassword, .tStatus, .tBody, .tHeaders)
    If $$$ISERR(tSC) || (tStatus '= 200) Quit ""
    Set tIterator = ##class(%DynamicObject).%FromJSON(tBody).areas.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tArea) {
        If tArea.key '= pArea Continue
        Set tVerdict = $Select(tArea.allowed: "true", 1: "false")
        If tArea.%IsDefined("failedPair") Set tVerdict = tVerdict _ ":" _ tArea.failedPair
    }
    Quit tVerdict
}

/// <p>Assert that <var>pUser</var>'s read of <var>pTool</var> is refused 403
/// <code>AUTH.NOPRIVILEGE</code> naming <var>pPair</var>.</p>
Method AssertReadRefused(pUser As %String, pTool As %String, pPair As %String)
{
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", "/api/ocupilot/screens/" _ pTool _ "/read?maxRows=5", pUser, ..PreparedPassword, .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, pUser _ " " _ pTool _ ": the read request completes")
    Do $$$AssertEquals(tStatus, 403, pUser _ " " _ pTool _ ": the read is refused")
    Set tRefusal = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tRefusal.code, "AUTH.NOPRIVILEGE", pUser _ " " _ pTool _ ": on the screen-privilege code")
    Do $$$AssertEquals($Select($IsObject(tRefusal.detail): tRefusal.detail.failedPair, 1: ""), pPair, pUser _ " " _ pTool _ ": naming " _ pPair)
}

/// <p>Story 2.8 AC5 -- the task schedule's pair set, proved with real principals. A caller holding
/// <code>%Admin_Task:USE</code> and not <code>%DB_IRISSYS:READ</code> is denied by name -- for the
/// screen, for the Tasks area and on the read route -- and granting the pair serves the list.</p>
/// <p><b>Why the denial has to be a real principal.</b> <code>%All</code> passes every resource
/// check, so the suite's own account could never observe it; and without the second pair the vendor
/// endpoint fails inside <code>%SYS</code> and the port answers 500, which is the failure the pair
/// turns into a named 403.</p>
/// <p>Mutation: remove <code>%DB_IRISSYS:READ</code> from
/// <class>OcuPilot.Screen.Descriptor.TaskScheduleList</class> -> the read answers 500 and the entry
/// and 403 assertions go red. Remove it from the <code>tasks</code> area in
/// <class>OcuPilot.Screen.Area</class> -> the area verdict goes red.</p>
Method TestTheTaskSchedulesPairSetIsEnforcedForARealPrincipal()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup confirmed the seven principals' pairs")

    Do $$$AssertEquals(..ScreensFor(..#TASKUSER, "tasks"), "[{""route"":""tasks/schedule"",""labelKey"":""taskListLabel"",""sideBarPosition"":1,""allowed"":false,""failedPair"":""%DB_IRISSYS:READ""}]", "%Admin_Task alone: the task schedule is denied on %DB_IRISSYS:READ")
    Do $$$AssertEquals(..AreaVerdictFor(..#TASKUSER, "tasks"), "false:%DB_IRISSYS:READ", "and so is the Tasks area")
    Do ..AssertReadRefused(..#TASKUSER, "tasks.schedule", "%DB_IRISSYS:READ")

    Do $$$AssertEquals(..ScreensFor(..#TASKBOTHUSER, "tasks"), "[{""route"":""tasks/schedule"",""labelKey"":""taskListLabel"",""sideBarPosition"":1,""allowed"":true}]", "both pairs: the task schedule is listed allowed")
    Do $$$AssertEquals(..AreaVerdictFor(..#TASKBOTHUSER, "tasks"), "true", "and so is the Tasks area")

    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", "/api/ocupilot/screens/tasks.schedule/read?maxRows=1000", ..#TASKBOTHUSER, ..PreparedPassword, .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the task schedule read completes")
    Do $$$AssertEquals(tStatus, 200, "and answers")
    If tStatus '= 200 Quit
    Set tAnswer = ##class(%DynamicObject).%FromJSON(tBody)
    Set tFields = "[""Name"",""Type"",""Namespace"",""Description"",""Id"",""LastFinished"",""NextScheduled""]"
    Do $$$AssertEquals(tAnswer.fields.%ToJSON(), tFields, "with the seven declared fields")
    Do $$$AssertTrue(tAnswer.rows.%Size() > 0, "and the instance's tasks listed: " _ tAnswer.rows.%Size())
    Set tBad = ""
    Set tIterator = tAnswer.rows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tKeys = []
        Set tKeyIterator = tRow.%GetIterator()
        While tKeyIterator.%GetNext(.tKey, .tValue) {
            Do tKeys.%Push(tKey)
        }
        If tKeys.%ToJSON() '= tFields Set tBad = "row " _ tIndex _ " carries " _ tKeys.%ToJSON()
        If tBad '= "" Quit
    }
    Do $$$AssertEquals(tBad, "", "every row carries exactly the seven declared fields, Suspended among none of them")
    ; The banner is screen chrome the read resolves (AD-36); on a throwaway whose Task Manager is
    ; running it is the empty string, and the suspended half is the browser spec's.
    Do $$$AssertEquals(tAnswer.%GetTypeOf("banner"), "string", "the answer carries the banner key as a string")
    Do $$$AssertEquals(tAnswer.banner, "", "empty while the Task Manager is running")
}

/// <p>Story 2.9 AC5 -- the processes list's three-pair set, proved with real principals. A caller
/// holding <code>%Admin_Operate:USE</code> and <code>%DB_IRISSYS:READ</code> and not
/// <code>%Admin_Manage:USE</code> is denied by name -- for the screen, for the OS management area and
/// on the read route -- and a caller holding all three is served the list, every row carrying exactly
/// the seven declared fields.</p>
/// <p><b>The middle pair is the one this leg exists for.</b> Probed on a throwaway: without
/// <code>%Admin_Manage:USE</code> the read answers <b>500</b>, not a named 403, because the query
/// behind the endpoint (<method>%SYS.ProcessQuery.CONTROLPANELExecute</method>, which checks that
/// resource or write on the IRISSYS database for itself) refuses and
/// <code>%Api.Admin.Util.ClassQuery</code> does not check what <code>%Execute()</code> answered.
/// Declaring the pair is what turns that into the refusal AD-8 asks for, and dropping it from the
/// descriptor is what makes this leg red.</p>
/// <p><b>The declared pair ORDER is pinned by a third principal.</b> The denied principal above
/// holds the first pair, so the second is the only unheld one under either ordering and a swap is
/// invisible to it. <parameter>SECUREUSER</parameter> holds neither administrative resource, so it
/// reads whichever pair the descriptor declares first -- which is what
/// <method>OcuPilot.Screen.Gate.EvaluatePairs</method> reports and what both client fixtures
/// carry.</p>
/// <p><b>Why the denial has to be a real principal.</b> <code>%All</code> passes every resource
/// check, so the suite's own account could never observe it.</p>
/// <p>Mutation: remove <code>%Admin_Manage:USE</code> from
/// <class>OcuPilot.Screen.Descriptor.ProcessList</class> and from the <code>os-management</code>
/// area -> the read answers 500 and the denial assertions go red. Swap the descriptor's first two
/// pairs -> the <parameter>SECUREUSER</parameter> assertions go red, and only they.</p>
Method TestTheProcessesListsPairSetIsEnforcedForARealPrincipal()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup confirmed the seven principals' pairs")

    Do $$$AssertEquals(..ScreensFor(..#OPERATEUSER, "os-management"), "[{""route"":""os-management/processes"",""labelKey"":""processListLabel"",""sideBarPosition"":1,""allowed"":false,""failedPair"":""%Admin_Manage:USE""}]", "%Admin_Operate and the database read: the processes list is denied on %Admin_Manage:USE")
    Do $$$AssertEquals(..AreaVerdictFor(..#OPERATEUSER, "os-management"), "false:%Admin_Manage:USE", "and so is the OS management area")
    Do ..AssertReadRefused(..#OPERATEUSER, "osmgmt.processes", "%Admin_Manage:USE")

    ; The pair ORDER, read by a principal holding neither administrative resource: %Admin_Operate:USE
    ; is declared first, so it is the pair the gate names. A descriptor that declared the first two
    ; the other way round would name %Admin_Manage:USE here, and nothing else in this class would move.
    Do $$$AssertEquals(..ScreensFor(..#SECUREUSER, "os-management"), "[{""route"":""os-management/processes"",""labelKey"":""processListLabel"",""sideBarPosition"":1,""allowed"":false,""failedPair"":""%Admin_Operate:USE""}]", "a principal holding neither administrative resource is denied on the first pair declared")
    Do $$$AssertEquals(..AreaVerdictFor(..#SECUREUSER, "os-management"), "false:%Admin_Operate:USE", "and so is the area, which declares them in the same order")

    Do $$$AssertEquals(..ScreensFor(..#PROCESSUSER, "os-management"), "[{""route"":""os-management/processes"",""labelKey"":""processListLabel"",""sideBarPosition"":1,""allowed"":true}]", "all three pairs: the processes list is listed allowed")
    Do $$$AssertEquals(..AreaVerdictFor(..#PROCESSUSER, "os-management"), "true", "and so is the OS management area")

    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", "/api/ocupilot/screens/osmgmt.processes/read?maxRows=1000", ..#PROCESSUSER, ..PreparedPassword, .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the processes read completes")
    Do $$$AssertEquals(tStatus, 200, "and answers")
    If tStatus '= 200 Quit
    Set tAnswer = ##class(%DynamicObject).%FromJSON(tBody)
    Set tFields = "[""Pid"",""Username"",""Nspace"",""Routine"",""State"",""Commands"",""Globals""]"
    Do $$$AssertEquals(tAnswer.fields.%ToJSON(), tFields, "with the seven declared fields, the vendor's Nspace spelling included")
    ; The caller is itself a process, so a zero-row answer would mean the read is not reading the
    ; instance at all.
    Do $$$AssertTrue(tAnswer.rows.%Size() > 0, "and the instance's processes listed: " _ tAnswer.rows.%Size())
    Set tBad = ""
    Set tNotNumber = ""
    Set tIterator = tAnswer.rows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tKeys = []
        Set tKeyIterator = tRow.%GetIterator()
        While tKeyIterator.%GetNext(.tKey, .tValue) {
            Do tKeys.%Push(tKey)
        }
        If tKeys.%ToJSON() '= tFields Set tBad = "row " _ tIndex _ " carries " _ tKeys.%ToJSON()
        ; The two `number` columns must arrive as JSON numbers, not as text. The client's shared
        ; view sorts numerically only on a number (OcuPilot's screen-read compare), while the right
        ; alignment and the tabular face come from the declared kind either way -- so a counter
        ; delivered as a string sorts "9" after "12345" with every other assertion still green.
        For tCounter = "Commands", "Globals" {
            If tRow.%GetTypeOf(tCounter) '= "number" {
                Set tNotNumber = "row " _ tIndex _ " carries " _ tCounter _ " as " _ tRow.%GetTypeOf(tCounter)
            }
        }
        If (tBad '= "") || (tNotNumber '= "") Quit
    }
    Do $$$AssertEquals(tBad, "", "every row carries exactly the seven declared fields, none of the four CanBe* gates among them")
    Do $$$AssertEquals(tNotNumber, "", "and both counter columns arrive as JSON numbers, which is what makes their sort numeric")
    ; A list screen that declares no banner answers the key as the empty string rather than omitting
    ; it, so the client's strip has one thing to read on every list. The type is asserted beside the
    ; value because an absent key reads back as "" too, so the value alone cannot tell the two apart.
    Do $$$AssertEquals(tAnswer.%GetTypeOf("banner"), "string", "the answer carries a banner key rather than omitting it")
    Do $$$AssertEquals(tAnswer.banner, "", "and the screen declares no banner, so none is raised")
}

/// <p>AC6 -- <code>%Admin_Secure:USE</code> alone: all three security lists, and the Permissions,
/// Web applications and Security and secrets areas themselves, are listed denied on
/// <code>%DB_IRISSYS:READ</code>, and all three reads are refused naming it.</p>
/// <p>Mutation: remove <code>%DB_IRISSYS:READ</code> from
/// <class>OcuPilot.Screen.Descriptor.UserList</class> -> the users read answers 500 and its entry
/// and 403 assertions go red; remove it from <class>OcuPilot.Screen.Descriptor.WebAppList</class> ->
/// the web applications leg goes red; remove it from
/// <class>OcuPilot.Screen.Descriptor.SslConfigList</class> -> the SSL/TLS leg goes red; remove it
/// from the <code>permissions</code> area in
/// <class>OcuPilot.Screen.Area</class> -> the Permissions area assertion goes red.</p>
Method TestAdminSecureAloneIsDeniedOnTheSystemDatabaseRead()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup confirmed the seven principals' pairs")
    Do $$$AssertEquals(..ScreensFor(..#SECUREUSER, "permissions"), "[{""route"":""permissions/users"",""labelKey"":""userListLabel"",""sideBarPosition"":1,""allowed"":false,""failedPair"":""%DB_IRISSYS:READ""}]", "the users list is denied on %DB_IRISSYS:READ")
    Do $$$AssertEquals(..ScreensFor(..#SECUREUSER, "web-applications"), "[{""route"":""web-applications/list"",""labelKey"":""webAppListLabel"",""sideBarPosition"":1,""allowed"":false,""failedPair"":""%DB_IRISSYS:READ""}]", "and so is the web applications list")
    Do $$$AssertEquals(..ScreensFor(..#SECUREUSER, "security"), "[{""route"":""security/ssl"",""labelKey"":""sslListLabel"",""sideBarPosition"":1,""allowed"":false,""failedPair"":""%DB_IRISSYS:READ""}]", "and so is the SSL/TLS configurations list")
    Do $$$AssertEquals(..AreaVerdictFor(..#SECUREUSER, "permissions"), "false:%DB_IRISSYS:READ", "the Permissions area is denied on %DB_IRISSYS:READ")
    Do $$$AssertEquals(..AreaVerdictFor(..#SECUREUSER, "web-applications"), "false:%DB_IRISSYS:READ", "and so is the Web applications area")
    Do $$$AssertEquals(..AreaVerdictFor(..#SECUREUSER, "security"), "false:%DB_IRISSYS:READ", "and so is the Security and secrets area")
    Do ..AssertReadRefused(..#SECUREUSER, "permissions.users", "%DB_IRISSYS:READ")
    Do ..AssertReadRefused(..#SECUREUSER, "webapp.list", "%DB_IRISSYS:READ")
    Do ..AssertReadRefused(..#SECUREUSER, "security.ssl", "%DB_IRISSYS:READ")
}

/// <p>AC6 -- <code>%DB_IRISSYS:READ</code> without <code>%Admin_Secure</code>: all three security
/// lists and their three areas are listed denied on <code>%Admin_Secure:USE</code>, and all three
/// reads are refused naming it.</p>
Method TestSystemReadWithoutAdminSecureIsDenied()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup confirmed the seven principals' pairs")
    Do $$$AssertEquals(..ScreensFor(..#SYSREADUSER, "permissions"), "[{""route"":""permissions/users"",""labelKey"":""userListLabel"",""sideBarPosition"":1,""allowed"":false,""failedPair"":""%Admin_Secure:USE""}]", "the users list is denied on %Admin_Secure:USE")
    Do $$$AssertEquals(..ScreensFor(..#SYSREADUSER, "web-applications"), "[{""route"":""web-applications/list"",""labelKey"":""webAppListLabel"",""sideBarPosition"":1,""allowed"":false,""failedPair"":""%Admin_Secure:USE""}]", "and so is the web applications list")
    Do $$$AssertEquals(..ScreensFor(..#SYSREADUSER, "security"), "[{""route"":""security/ssl"",""labelKey"":""sslListLabel"",""sideBarPosition"":1,""allowed"":false,""failedPair"":""%Admin_Secure:USE""}]", "and so is the SSL/TLS configurations list")
    Do $$$AssertEquals(..AreaVerdictFor(..#SYSREADUSER, "permissions"), "false:%Admin_Secure:USE", "the Permissions area is denied on %Admin_Secure:USE")
    Do $$$AssertEquals(..AreaVerdictFor(..#SYSREADUSER, "web-applications"), "false:%Admin_Secure:USE", "and so is the Web applications area")
    Do $$$AssertEquals(..AreaVerdictFor(..#SYSREADUSER, "security"), "false:%Admin_Secure:USE", "and so is the Security and secrets area")
    Do ..AssertReadRefused(..#SYSREADUSER, "permissions.users", "%Admin_Secure:USE")
    Do ..AssertReadRefused(..#SYSREADUSER, "webapp.list", "%Admin_Secure:USE")
    Do ..AssertReadRefused(..#SYSREADUSER, "security.ssl", "%Admin_Secure:USE")
}

/// <p>AC6 -- both pairs: all three lists and their three areas are listed allowed, all three reads
/// answer 200, every users row
/// carries a <code>Roles</code> array from its detail call, and every SSL/TLS row carries exactly the
/// four declared fields.</p>
Method TestBothPairsReadEveryList()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup confirmed the seven principals' pairs")
    Do $$$AssertEquals(..ScreensFor(..#BOTHUSER, "permissions"), "[{""route"":""permissions/users"",""labelKey"":""userListLabel"",""sideBarPosition"":1,""allowed"":true}]", "the users list is listed allowed")
    Do $$$AssertEquals(..ScreensFor(..#BOTHUSER, "web-applications"), "[{""route"":""web-applications/list"",""labelKey"":""webAppListLabel"",""sideBarPosition"":1,""allowed"":true}]", "and so is the web applications list")
    Do $$$AssertEquals(..ScreensFor(..#BOTHUSER, "security"), "[{""route"":""security/ssl"",""labelKey"":""sslListLabel"",""sideBarPosition"":1,""allowed"":true}]", "and so is the SSL/TLS configurations list")
    Do $$$AssertEquals(..AreaVerdictFor(..#BOTHUSER, "permissions"), "true", "the Permissions area is allowed")
    Do $$$AssertEquals(..AreaVerdictFor(..#BOTHUSER, "web-applications"), "true", "and so is the Web applications area")
    Do $$$AssertEquals(..AreaVerdictFor(..#BOTHUSER, "security"), "true", "and so is the Security and secrets area")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", "/api/ocupilot/screens/webapp.list/read?maxRows=5", ..#BOTHUSER, ..PreparedPassword, .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the web applications read completes")
    Do $$$AssertEquals(tStatus, 200, "and answers")

    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", "/api/ocupilot/screens/security.ssl/read?maxRows=1000", ..#BOTHUSER, ..PreparedPassword, .tStatus3, .tBody3, .tHeaders3)
    Do $$$AssertStatusOK(tSC, "the SSL/TLS read completes")
    Do $$$AssertEquals(tStatus3, 200, "and answers")
    If tStatus3 = 200 {
        Set tSsl = ##class(%DynamicObject).%FromJSON(tBody3)
        Set tSslFields = "[""Name"",""Description"",""Enabled"",""Type""]"
        Do $$$AssertEquals(tSsl.fields.%ToJSON(), tSslFields, "with the four declared fields")
        Do $$$AssertTrue(tSsl.rows.%Size() > 0, "and the instance's configurations listed: " _ tSsl.rows.%Size())
        Set tSslBad = ""
        Set tSslIterator = tSsl.rows.%GetIterator()
        While tSslIterator.%GetNext(.tSslIndex, .tSslRow) {
            Set tSslKeys = []
            Set tSslKeyIterator = tSslRow.%GetIterator()
            While tSslKeyIterator.%GetNext(.tSslKey, .tSslValue) {
                Do tSslKeys.%Push(tSslKey)
            }
            If tSslKeys.%ToJSON() '= tSslFields Set tSslBad = "row " _ tSslIndex _ " carries " _ tSslKeys.%ToJSON()
            If tSslBad '= "" Quit
        }
        Do $$$AssertEquals(tSslBad, "", "every SSL/TLS row carries exactly the four declared fields")
    }

    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", "/api/ocupilot/screens/permissions.users/read?maxRows=1000", ..#BOTHUSER, ..PreparedPassword, .tStatus2, .tBody2, .tHeaders2)
    Do $$$AssertStatusOK(tSC, "the users read completes")
    Do $$$AssertEquals(tStatus2, 200, "and answers")
    If tStatus2 '= 200 Quit
    Set tRows = ##class(%DynamicObject).%FromJSON(tBody2).rows
    Do $$$AssertTrue(tRows.%Size() > 0, "with users listed: " _ tRows.%Size())
    Set tBad = ""
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If tRow.%GetTypeOf("Roles") '= "array" Set tBad = tRow.Name _ " has a Roles that is " _ tRow.%GetTypeOf("Roles")
        If tBad '= "" Quit
    }
    Do $$$AssertEquals(tBad, "", "every row carries a Roles array")
}

}

/// <p>Pins <class>OcuPilot.Kernel.Shell.Findings</class>'s nine rules, its answer shape and its
/// three unread states over <class>OcuPilot.Test.FindingsFixture</class>'s rows (Story 16.21). One
/// leg asks the instance for <code>_SYSTEM</code>'s real removal verdict; nothing is written.</p>
Class OcuPilot.Test.Findings Extends %UnitTest.TestCase
{

Parameter FIXTURE = "OcuPilot.Test.FindingsFixture";

Parameter WEBAPPS = "OcuPilot.Screen.Descriptor.WebAppList";

Parameter USERS = "OcuPilot.Screen.Descriptor.UserList";

Parameter X509 = "OcuPilot.Screen.Descriptor.X509CredentialList";

Parameter AUDITING = "OcuPilot.Screen.Descriptor.AuditingConfig";

Parameter DATABASES = "OcuPilot.Screen.Descriptor.DatabaseList";

Parameter TASKS = "OcuPilot.Screen.Descriptor.TaskScheduleList";

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Test.FindingsFixture).Clear()
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Test.FindingsFixture).Clear()
    Quit $$$OK
}

/// <p>The answer, read through the fixture.</p>
Method Answer() As %DynamicObject
{
    Set tSC = ##class(OcuPilot.Test.FindingsFixture).Read(.tAnswer)
    Do $$$AssertStatusOK(tSC, "the answer is built")
    Quit tAnswer
}

/// <p><var>pCheck</var>'s row of <var>pAnswer</var>'s checks, or <code>""</code>.</p>
ClassMethod CheckRow(pAnswer As %DynamicObject, pCheck As %String) As %DynamicObject
{
    Set tFound = ""
    Set tIterator = pAnswer.%Get("checks").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If tRow.%Get("check") = pCheck Set tFound = tRow Quit
    }
    Quit tFound
}

/// <p>The names of <var>pAnswer</var>'s findings for <var>pCheck</var>, joined by
/// <code>,</code>.</p>
ClassMethod Names(pAnswer As %DynamicObject, pCheck As %String) As %String
{
    Set tNames = ""
    Set tIterator = pAnswer.%Get("findings").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tFinding) {
        If tFinding.%Get("check") '= pCheck Continue
        Set tNames = tNames _ $Select(tNames = "": "", 1: ",") _ tFinding.%Get("name")
    }
    Quit tNames
}

/// <p><var>pAnswer</var>'s first finding for <var>pCheck</var>, or <code>""</code>.</p>
ClassMethod First(pAnswer As %DynamicObject, pCheck As %String) As %DynamicObject
{
    Set tFound = ""
    Set tIterator = pAnswer.%Get("findings").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tFinding) {
        If tFinding.%Get("check") = pCheck Set tFound = tFinding Quit
    }
    Quit tFound
}

/// <p>A web application row and its <code>GET</code>, holding <var>pRoles</var> as application
/// roles.</p>
ClassMethod App(pName As %String, pAuthe As %Integer, pRoles As %DynamicArray, pEnabled As %Boolean = 1, pDispatch As %String = "") As %DynamicObject
{
    Set tRow = {"Name": (pName), "DispatchClass": (pDispatch)}
    Do tRow.%Set("Enabled", pEnabled, "boolean")
    Do ##class(OcuPilot.Test.FindingsFixture).SetDetail("WebApp.App", pName, {"AutheEnabled": (pAuthe), "MatchRoles": [{"MatchRole": "", "TargetRoles": (pRoles)}, {"MatchRole": "%DB_IRISSYS", "TargetRoles": ["%All"]}]})
    Quit tRow
}

/// <p>A clean instance: nine checks, each <code>checked</code> in its group and in declared order,
/// and no finding.</p>
Method TestACleanInstanceChecksAllNineAndFindsNothing()
{
    Set tAnswer = ..Answer()
    Set tSeen = ""
    Set tIterator = tAnswer.%Get("checks").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tSeen = tSeen _ $ListBuild(tRow.%Get("check") _ "/" _ tRow.%Get("group") _ "/" _ tRow.%Get("status"))
    }
    Set tWanted = $ListBuild("webapp-open/security/checked", "monitor-open/security/checked", "all-holder/security/checked", "certificate/security/checked", "auditing-off/security/checked", "database-dismounted/operations/checked", "database-full/operations/checked", "task-manager/operations/checked", "task-error/operations/checked")
    Do $$$AssertEquals($ListToString(tSeen), $ListToString(tWanted), "nine checks, in order, each read")
    Do $$$AssertEquals(tAnswer.%Get("findings").%Size(), 0, "and nothing to report")
}

/// <p><code>webapp-open</code>: an unauthenticated application whose roles grant database write,
/// administrative use or <code>%All</code> (directly or through a granted role) is a finding, and
/// read-only, public-only, a matching role, authenticated and disabled applications are not.</p>
/// <p>Mutation: count a letter held only publicly as privileged in
/// <method>OcuPilot.Kernel.Shell.Findings.Privileged</method> -&gt; <code>/pub</code> is reported
/// and this goes red.</p>
Method TestAnOpenApplicationHoldingPrivilegeIsAFindingAndNothingElseIs()
{
    Set tRows = []
    Do tRows.%Push(..App("/dbw", 64, ["DbWriter"]))
    Do tRows.%Push(..App("/admin", 96, ["Operator"]))
    Do tRows.%Push(..App("/dev", 64, ["%Developer"]))
    Do tRows.%Push(..App("/via", 64, ["Wrapper"]))
    Do tRows.%Push(..App("/all", 64, ["%All"]))
    Do tRows.%Push(..App("/dbr", 64, ["DbReader"]))
    Do tRows.%Push(..App("/pub", 64, ["Nothing"]))
    Do tRows.%Push(..App("/signed", 32, ["%All"]))
    Do tRows.%Push(..App("/off", 64, ["%All"], 0))
    Do tRows.%Push(..App("/matching", 64, []))
    Do ##class(OcuPilot.Test.FindingsFixture).SetRows(..#WEBAPPS, tRows)
    Set tRoleRows = {}
    Do tRoleRows.%Set("DbWriter", {"GrantedRoles": [], "Resources": [{"Name": "%DB_USER", "Permissions": "RW"}]})
    Do tRoleRows.%Set("Operator", {"GrantedRoles": [], "Resources": [{"Name": "%Admin_Operate", "Permissions": "U"}]})
    Do tRoleRows.%Set("%Developer", {"GrantedRoles": [], "Resources": [{"Name": "%Development", "Permissions": "U"}]})
    Do tRoleRows.%Set("Wrapper", {"GrantedRoles": ["%All"], "Resources": []})
    Do tRoleRows.%Set("DbReader", {"GrantedRoles": [], "Resources": [{"Name": "%DB_USER", "Permissions": "R"}]})
    Do tRoleRows.%Set("Nothing", {"GrantedRoles": [], "Resources": []})
    Do ##class(OcuPilot.Test.FindingsFixture).SetEffective(tRoleRows, {"%DB_USER": "RW", "%Admin_Manage": "U"})
    Set tAnswer = ..Answer()
    Do $$$AssertEquals(..CheckRow(tAnswer, "webapp-open").%Get("status"), "checked", "the check was read")
    Do $$$AssertEquals(..Names(tAnswer, "webapp-open"), "/dbw,/admin,/dev,/via,/all", "database write, administrative use, development, a granted %All and %All are findings; read-only, public-only, signed-in, disabled and matching-role applications are not")
    Set tFinding = ..First(tAnswer, "webapp-open")
    Do $$$AssertEquals(tFinding.%Get("id") _ " " _ tFinding.%Get("route") _ " " _ tFinding.%Get("scope") _ " " _ tFinding.%Get("fix") _ " " _ tFinding.%Get("group"), "/dbw web-applications/list instance agent security", "a finding names its object's route, id and scope, and its fix is the agent's")
}

/// <p><code>monitor-open</code>: the monitoring API's application, known by its dispatch class,
/// open without signing in is reported by its own check and never also by <code>webapp-open</code>;
/// signed in, it is not reported.</p>
Method TestTheMonitoringApiIsReportedOnceByItsOwnCheck()
{
    Set tRows = []
    Do tRows.%Push(..App("/api/monitor", 64, ["%DB_IRISSYS"], 1, "%Api.Monitor"))
    Do ##class(OcuPilot.Test.FindingsFixture).SetRows(..#WEBAPPS, tRows)
    Do ##class(OcuPilot.Test.FindingsFixture).SetEffective({"%DB_IRISSYS": {"GrantedRoles": [], "Resources": [{"Name": "%DB_IRISSYS", "Permissions": "RW"}]}}, {})
    Set tAnswer = ..Answer()
    Do $$$AssertEquals(..Names(tAnswer, "monitor-open"), "/api/monitor", "the monitoring API open without signing in is a finding")
    Do $$$AssertEquals(..Names(tAnswer, "webapp-open"), "", "and is not reported twice")
    Do $$$AssertEquals(..First(tAnswer, "monitor-open").%Get("fix"), "agent", "its fix is the agent's")

    Do ##class(OcuPilot.Test.FindingsFixture).SetRows(..#WEBAPPS, [(..App("/api/monitor", 32, ["%DB_IRISSYS"], 1, "%Api.Monitor"))])
    Do $$$AssertEquals(..Names(..Answer(), "monitor-open"), "", "signed in, it is not a finding")
}

/// <p><code>all-holder</code>: an enabled account holding <code>%All</code> directly or through a
/// granted role is a finding with the agent's fix; a disabled one is not; a refused removal reads
/// <code>refused</code> with the prohibited set's own code and sentence, here asked of the
/// instance for <code>_SYSTEM</code>.</p>
Method TestAllHoldersAreFindingsAndARefusedRemovalCarriesTheSetsOwnSentence()
{
    Set tRows = []
    Do tRows.%Push({"Name": "direct", "Enabled": true, "Roles": ["%All"]})
    Do tRows.%Push({"Name": "granted", "Enabled": true, "Roles": ["Wrapper"]})
    Do tRows.%Push({"Name": "disabled", "Enabled": false, "Roles": ["%All"]})
    Do tRows.%Push({"Name": "plain", "Enabled": true, "Roles": ["%Operator"]})
    Do tRows.%Push({"Name": "_SYSTEM", "Enabled": true, "Roles": ["%All"]})
    Do ##class(OcuPilot.Test.FindingsFixture).SetRows(..#USERS, tRows)
    Do ##class(OcuPilot.Test.FindingsFixture).SetEffective({"Wrapper": {"GrantedRoles": ["%All"], "Resources": []}}, {})
    Do ##class(OcuPilot.Test.FindingsFixture).SetVerdict("direct", "")
    Do ##class(OcuPilot.Test.FindingsFixture).SetVerdict("granted", "")
    Set tAnswer = ..Answer()
    Do $$$AssertEquals(..Names(tAnswer, "all-holder"), "direct,granted,_SYSTEM", "enabled holders, direct or granted, and never a disabled one")
    Set tDirect = ..First(tAnswer, "all-holder")
    Do $$$AssertEquals(tDirect.%Get("fix") _ " " _ tDirect.%Get("route"), "agent permissions/users", "a removable holder offers the agent's fix on the Users list")
    Do $$$AssertEquals(tDirect.%GetTypeOf("refused"), "unassigned", "and carries no refusal")
    Set tSystem = ""
    Set tIterator = tAnswer.%Get("findings").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tFinding) {
        If tFinding.%Get("name") = "_SYSTEM" Set tSystem = tFinding
    }
    Do $$$AssertTrue($IsObject(tSystem), "_SYSTEM is a finding")
    If '$IsObject(tSystem) Quit
    Set tCode = ##class(OcuPilot.Kernel.Proposal.Prohibited).#SYSTEMACCOUNT
    Do $$$AssertEquals(tSystem.%Get("fix"), "refused", "the prohibited set refuses taking %All off _SYSTEM")
    Do $$$AssertEquals(tSystem.%Get("refused").%Get("code"), tCode, "naming its code")
    Do $$$AssertEquals(tSystem.%Get("refused").%Get("reason"), ##class(OcuPilot.Kernel.Proposal.Prohibited).ReasonFor(tCode), "and its own published sentence")
}

/// <p><code>certificate</code>: expired a second ago, and expiring exactly 30 days out, are
/// findings; 30 days and one second out is not. <code>detail</code> is the date and
/// <code>expired</code> says which.</p>
Method TestCertificatesExpiredOrWithinThirtyDaysAreFindings()
{
    Set tNow = "67000,43200.5"
    Do ##class(OcuPilot.Test.FindingsFixture).SetNow(tNow)
    Set tRows = []
    Do tRows.%Push({"Alias": "gone", "ValidityNotAfter": ($ZDateTime("67000,43199", 3))})
    Do tRows.%Push({"Alias": "day30", "ValidityNotAfter": ($ZDateTime("67030,43200", 3))})
    Do tRows.%Push({"Alias": "day31", "ValidityNotAfter": ($ZDateTime("67030,43201", 3))})
    Do tRows.%Push({"Alias": "undated", "ValidityNotAfter": ""})
    Do ##class(OcuPilot.Test.FindingsFixture).SetRows(..#X509, tRows)
    Set tAnswer = ..Answer()
    Do $$$AssertEquals(..Names(tAnswer, "certificate"), "gone,day30", "an expired certificate and one on the thirtieth day are findings; one a second later is not")
    Set tGone = ..First(tAnswer, "certificate")
    Do $$$AssertEquals(tGone.%Get("detail") _ " " _ tGone.%Get("expired") _ " " _ tGone.%Get("fix"), $ZDate(67000, 3) _ " 1 link", "its date, that it expired, and a link rather than a fix")
    Do $$$AssertEquals(tAnswer.%Get("findings").%Get(1).%Get("expired"), 0, "the one still valid is expiring, not expired")
}

/// <p><code>auditing-off</code>: auditing off is a finding with the agent's fix; on is not.</p>
Method TestAuditingOffIsAFinding()
{
    Do ##class(OcuPilot.Test.FindingsFixture).SetRows(..#AUDITING, [{"Enabled": false}])
    Set tFinding = ..First(..Answer(), "auditing-off")
    Do $$$AssertTrue($IsObject(tFinding), "auditing off is a finding")
    If $IsObject(tFinding) Do $$$AssertEquals(tFinding.%Get("route") _ " " _ tFinding.%Get("fix") _ " [" _ tFinding.%Get("id") _ "]", "security/auditing agent []", "on the auditing screen, fixed by the agent")
    Do ##class(OcuPilot.Test.FindingsFixture).SetRows(..#AUDITING, [{"Enabled": true}])
    Do $$$AssertEquals(..First(..Answer(), "auditing-off"), "", "auditing on is not")
}

/// <p><code>database-dismounted</code> and <code>database-full</code>: a dismounted database is a
/// finding; a mounted one at exactly 85% of a numeric maximum is, at 84.9% it is not, and an
/// unlimited or zero maximum never is. A dismounted database is never also reported full.</p>
/// <p>Mutation: compare with <code>&gt;</code> instead of <code>&gt;=</code> in
/// <method>OcuPilot.Kernel.Shell.Findings.Databases</method> -&gt; <code>/at85/</code> is not
/// reported and this goes red.</p>
Method TestDatabasesDismountedOrAtEightyFivePercentAreFindings()
{
    Set tRows = []
    Do tRows.%Push({"Directory": "/gone/", "Size": 900, "MaxSize": "1000", "Status": "Dismounted"})
    Do tRows.%Push({"Directory": "/at85/", "Size": 850, "MaxSize": "1000", "Status": "Mounted/RW"})
    Do tRows.%Push({"Directory": "/at849/", "Size": 849, "MaxSize": "1000", "Status": "Mounted/RW"})
    Do tRows.%Push({"Directory": "/unlimited/", "Size": 999, "MaxSize": "Unlimited", "Status": "Mounted/RW"})
    Do tRows.%Push({"Directory": "/zero/", "Size": 999, "MaxSize": 0, "Status": "Mounted/R"})
    Do ##class(OcuPilot.Test.FindingsFixture).SetRows(..#DATABASES, tRows)
    Set tAnswer = ..Answer()
    Do $$$AssertEquals(..Names(tAnswer, "database-dismounted"), "/gone/", "a dismounted database is a finding and a mounted one is not")
    Do $$$AssertEquals(..Names(tAnswer, "database-full"), "/at85/", "85% is a finding, 84.9%, unlimited, zero and dismounted are not")
    Set tFull = ..First(tAnswer, "database-full")
    Do $$$AssertEquals(tFull.%Get("detail") _ " " _ tFull.%Get("route") _ " " _ tFull.%Get("fix"), "85 os-management/databases/details link", "its percent, on its details, as a link")
    Do $$$AssertEquals(..First(tAnswer, "database-dismounted").%Get("fix"), "link", "a dismount is a link too")
}

/// <p><code>task-manager</code> and <code>task-error</code>: a suspended or stopped Task Manager is
/// a finding carrying its banner key; a task suspended after an error is, and one suspended by a
/// person, one whose last run succeeded, and one not suspended are not.</p>
Method TestTaskManagerAndTasksSuspendedAfterAnError()
{
    Set tRows = []
    Do tRows.%Push({"Name": "failed", "Id": 1002, "Suspended": true})
    Do tRows.%Push({"Name": "paused", "Id": 4, "Suspended": true})
    Do tRows.%Push({"Name": "succeeded", "Id": 5, "Suspended": true})
    Do tRows.%Push({"Name": "running", "Id": 6, "Suspended": false})
    Do ##class(OcuPilot.Test.FindingsFixture).SetRows(..#TASKS, tRows, 0, "taskManagerSuspendedBanner")
    Do ##class(OcuPilot.Test.FindingsFixture).SetDetail("Task.CRUD", 1002, {"Error": "<THROW>OnTask+1 a failure"})
    Do ##class(OcuPilot.Test.FindingsFixture).SetDetail("Task.CRUD", 4, {"Error": ""})
    Do ##class(OcuPilot.Test.FindingsFixture).SetDetail("Task.CRUD", 5, {"Error": "Success"})
    Do ##class(OcuPilot.Test.FindingsFixture).SetDetail("Task.CRUD", 6, {"Error": "an error from before"})
    Set tAnswer = ..Answer()
    Do $$$AssertEquals(..Names(tAnswer, "task-error"), "failed", "only the task suspended after an error")
    Set tTask = ..First(tAnswer, "task-error")
    Do $$$AssertEquals(tTask.%Get("id") _ " " _ tTask.%Get("route") _ " " _ tTask.%Get("fix"), "1002 tasks/schedule/details agent", "on its details, fixed by the agent")
    Set tManager = ..First(tAnswer, "task-manager")
    Do $$$AssertTrue($IsObject(tManager), "a suspended Task Manager is a finding")
    If $IsObject(tManager) Do $$$AssertEquals(tManager.%Get("detail") _ " " _ tManager.%Get("route") _ " " _ tManager.%Get("fix"), "taskManagerSuspendedBanner tasks/schedule link", "carrying the banner key, as a link")
    Do ##class(OcuPilot.Test.FindingsFixture).SetRows(..#TASKS, [], 0, "")
    Do $$$AssertEquals(..First(..Answer(), "task-manager"), "", "a running Task Manager is not")
}

/// <p>Unread: a caller short of a screen's pair reads every check on that screen
/// <code>unchecked</code> naming the pair, with no finding; a caller short of the role read reads
/// <code>webapp-open</code> and <code>all-holder</code> unchecked naming that pair, with no
/// finding. None says "nothing to report".</p>
Method TestAnUnreadableCheckIsUncheckedNamingThePair()
{
    Do ##class(OcuPilot.Test.FindingsFixture).SetRows(..#WEBAPPS, [(..App("/all", 64, ["%All"])), (..App("/api/monitor", 64, ["%DB_IRISSYS"], 1, "%Api.Monitor"))])
    Do ##class(OcuPilot.Test.FindingsFixture).SetGate(..#WEBAPPS, "%Admin_Secure:USE")
    Set tAnswer = ..Answer()
    For tCheck = "webapp-open", "monitor-open" {
        Set tRow = ..CheckRow(tAnswer, tCheck)
        Do $$$AssertEquals(tRow.%Get("status") _ " " _ tRow.%Get("pair"), "unchecked %Admin_Secure:USE", tCheck _ " is unchecked, naming the pair")
        Do $$$AssertEquals(..Names(tAnswer, tCheck), "", tCheck _ " contributes no finding")
    }
    Do $$$AssertEquals(..CheckRow(tAnswer, "all-holder").%Get("status"), "checked", "a screen the caller may read is still read")

    Do ##class(OcuPilot.Test.FindingsFixture).Clear()
    Do ##class(OcuPilot.Test.FindingsFixture).SetRows(..#WEBAPPS, [(..App("/all", 64, ["DbWriter"]))])
    Do ##class(OcuPilot.Test.FindingsFixture).SetEffective({}, {}, "%DB_IRISSYS:READ")
    Set tRow = ..CheckRow(..Answer(), "webapp-open")
    Do $$$AssertEquals(tRow.%Get("status") _ " " _ tRow.%Get("pair"), "unchecked %DB_IRISSYS:READ", "an unreadable role read leaves the check unchecked, naming that pair")

    Do ##class(OcuPilot.Test.FindingsFixture).Clear()
    Do ##class(OcuPilot.Test.FindingsFixture).SetRows(..#USERS, [{"Name": "direct", "Enabled": true, "Roles": ["%All"]}, {"Name": "granted", "Enabled": true, "Roles": ["Wrapper"]}])
    Do ##class(OcuPilot.Test.FindingsFixture).SetEffective({}, {}, "%DB_IRISSYS:READ")
    Set tAnswer = ..Answer()
    Set tRow = ..CheckRow(tAnswer, "all-holder")
    Do $$$AssertEquals(tRow.%Get("status") _ " " _ tRow.%Get("pair"), "unchecked %DB_IRISSYS:READ", "an unreadable role read leaves all-holder unchecked, naming that pair")
    Do $$$AssertEquals(..Names(tAnswer, "all-holder"), "", "and lists no holder, not even a direct one")
}

/// <p>Too many: a users read cut at its cap reads <code>all-holder</code> <code>truncated</code>,
/// and reports nothing from the rows it did read.</p>
Method TestAReadCutAtItsCapIsTruncated()
{
    Do ##class(OcuPilot.Test.FindingsFixture).SetRows(..#USERS, [{"Name": "direct", "Enabled": true, "Roles": ["%All"]}], 1)
    Set tAnswer = ..Answer()
    Do $$$AssertEquals(..CheckRow(tAnswer, "all-holder").%Get("status"), "truncated", "the check is truncated")
    Do $$$AssertEquals(..Names(tAnswer, "all-holder"), "", "and contributes no finding")
}

/// <p>Edges: a detail call that answers 404 skips that row and the check stays read; a role read cut
/// at its cap reads <code>truncated</code>; a task read cut at its cap keeps
/// <code>task-manager</code> read, since the banner does not depend on the rows, while
/// <code>task-error</code> is <code>truncated</code>; and a check over a read of its own that raises
/// is the one <code>failed</code>, logged once, while the other eight answer.</p>
Method TestDetailGoneRoleReadCutTaskReadCutAndOneOwnReadFailing()
{
    Do ##class(OcuPilot.Test.FindingsFixture).SetRows(..#WEBAPPS, [{"Name": "/gone", "Enabled": true, "DispatchClass": ""}])
    Do ##class(OcuPilot.Test.FindingsFixture).SetRows(..#TASKS, [{"Name": "failed", "Id": 1002, "Suspended": true}], 1, "taskManagerStoppedBanner")
    Do ##class(OcuPilot.Test.FindingsFixture).SetReadThrows(..#X509)
    Set tAnswer = ..Answer()
    Do $$$AssertEquals(..CheckRow(tAnswer, "webapp-open").%Get("status") _ " " _ ..CheckRow(tAnswer, "monitor-open").%Get("status"), "checked checked", "an application gone before its GET is skipped, not a failure")
    Do $$$AssertEquals(..CheckRow(tAnswer, "task-manager").%Get("status"), "checked", "a cut task read still answers the Task Manager")
    Do $$$AssertEquals(..First(tAnswer, "task-manager").%Get("detail"), "taskManagerStoppedBanner", "and reports it")
    Do $$$AssertEquals(..CheckRow(tAnswer, "task-error").%Get("status"), "truncated", "while the rows it cut are truncated")
    Do $$$AssertEquals(..CheckRow(tAnswer, "certificate").%Get("status"), "failed", "the check whose own read raised failed")
    Do $$$AssertEquals(##class(OcuPilot.Test.FindingsFixture).LogCalls() _ " " _ ##class(OcuPilot.Test.FindingsFixture).Logged(), "1 certificate", "logged once, naming it")
    Set tChecked = 0
    Set tIterator = tAnswer.%Get("checks").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If tRow.%Get("status") = "checked" Set tChecked = tChecked + 1
    }
    Do $$$AssertEquals(tChecked, 7, "every check but the failed one and the cut one answers")

    Do ##class(OcuPilot.Test.FindingsFixture).Clear()
    Do ##class(OcuPilot.Test.FindingsFixture).SetRows(..#WEBAPPS, [(..App("/all", 64, ["Wrapper"]))])
    Do ##class(OcuPilot.Test.FindingsFixture).SetEffective({}, {}, ##class(OcuPilot.Kernel.Shell.Effective).#TRUNCATED)
    Set tRow = ..CheckRow(..Answer(), "webapp-open")
    Do $$$AssertEquals(tRow.%Get("status") _ " [" _ tRow.%Get("pair") _ "]", "truncated []", "a role read cut at its cap is truncated, naming no pair")
}

/// <p>Source fails: a read that raises makes each check over it <code>failed</code>, logged once
/// each naming the check, and every other check still answers.</p>
/// <p>Mutation: answer <code>checked</code> for a check whose <method>Field</method> degraded in
/// <method>OcuPilot.Kernel.Shell.Findings.Read</method> -&gt; this goes red.</p>
Method TestAFailingSourceIsFailedAndLoggedAndTheOthersAnswer()
{
    Do ##class(OcuPilot.Test.FindingsFixture).SetReadThrows(..#DATABASES)
    Set tAnswer = ..Answer()
    Do $$$AssertEquals(..CheckRow(tAnswer, "database-dismounted").%Get("status"), "failed", "the dismount check failed")
    Do $$$AssertEquals(..CheckRow(tAnswer, "database-full").%Get("status"), "failed", "and so did the size check over the same read")
    Do $$$AssertEquals(##class(OcuPilot.Test.FindingsFixture).LogCalls(), 2, "each failure reached the log once")
    Do $$$AssertEquals(##class(OcuPilot.Test.FindingsFixture).Logged(), "database-full", "naming the check")
    Set tChecked = 0
    Set tIterator = tAnswer.%Get("checks").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If tRow.%Get("status") = "checked" Set tChecked = tChecked + 1
    }
    Do $$$AssertEquals(tChecked, 7, "the other seven answer")
}

}

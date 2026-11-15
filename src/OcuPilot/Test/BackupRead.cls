/// <p>Pins Story 21.2's three reads, the write state and the gate (AC1, AC2, AC3's refusals; AD-23, AD-29, AD-36): Backup tasks, Backup
/// history and Backup database list read through <class>OcuPilot.Port.BackupPort</class> and the screens' own read executor, the history
/// through the harvested body behind <class>OcuPilot.Port.HarvestPort</class>, and every read and write refused to a caller short of a
/// pair before any vendor call or body. The five write keys ship disabled and the agent is refused at dispatch.</p>
/// <p><b>Live-safe:</b> it reads, writes nothing to a backup, the list or the write state, and stores a governance policy only to
/// restore it. <b>What it needs from the environment:</b> OcuPilot installed and serving, database writes thawed, and the four built-in
/// backup tasks.</p>
Class OcuPilot.Test.BackupRead Extends %UnitTest.TestCase
{

Parameter PORT = "OcuPilot.Port.BackupPort";

Parameter SEAM = "OcuPilot.Test.BackupGateSeam";

Parameter RECORDER = "OcuPilot.Test.BackupHarvestRecorder";

Parameter TASKS = "OcuPilot.Screen.Descriptor.BackupTaskList";

Parameter HISTORY = "OcuPilot.Screen.Descriptor.BackupHistoryList";

Parameter DATABASES = "OcuPilot.Screen.Descriptor.BackupDatabaseList";

/// <p>The four tasks the instance ships, in the order the vendor lists them.</p>
Parameter BUILTIN = "FullAllDatabases,FullDBList,IncrementalDBList,CumuIncrDBList";

/// <p>The five write keys, each shipped <code>false</code> (AD-22).</p>
Parameter KEYS = "osmgmt.backuptasks.run,osmgmt.backuptasks.freeze,osmgmt.backuptasks.thaw,osmgmt.backupdatabases.add,osmgmt.backupdatabases.remove";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

/// <p>The governance policy as it stood before each test.</p>
Property StoredPolicy [ MultiDimensional ];

Method OnBeforeOneTest() As %Status
{
    Kill ..StoredPolicy
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tRows)
    If $$$ISERR(tSC) Quit tSC
    Merge ..StoredPolicy = tRows
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do $ClassMethod(..#SEAM, "Reset")
    Do $ClassMethod(..#RECORDER, "Clear")
    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Quit ##class(OcuPilot.Test.GovernanceFixture).Clear()
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do $ClassMethod(..#SEAM, "Reset")
    Do $ClassMethod(..#RECORDER, "Clear")
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Kill tRows
    Merge tRows = ..StoredPolicy
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows), "the policy found before the test is put back")
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining)
    Quit $$$OK
}

/// <p>Hold every pair the port's two sets name, in the gate's test seam.</p>
ClassMethod HoldAll()
{
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Admin_Operate", "USE")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_IRISSYS", "READ")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_IRISSYS", "WRITE")
}

/// <p>The screen's read of <var>pDescriptor</var> through the shipped executor, answering its result object.</p>
ClassMethod Read(pDescriptor As %String, Output pHttp As %Integer, Output pFault As %DynamicObject) As %DynamicObject
{
    Set tSC = ##class(OcuPilot.Screen.Read).Execute(pDescriptor, "", .tResult, .pHttp, .pFault)
    If $$$ISERR(tSC) Quit ""
    Quit tResult
}

/// <p>A read's rows' <var>pField</var> values, comma-joined.</p>
ClassMethod Column(pResult As %DynamicObject, pField As %String) As %String
{
    Set tOut = ""
    If '$IsObject(pResult) Quit ""
    Set tIterator = pResult.%Get("rows").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tOut = tOut _ $Select(tOut = "": "", 1: ",") _ tRow.%Get(pField)
    }
    Quit tOut
}

/// <p><b>AC1.</b> Backup tasks answers one row per task the vendor lists, the four built-in tasks first, each a system task, with its
/// type, last run, status and description, and the write state the banner reads.</p>
/// <p>Mutation (Rule 19): <class>OcuPilot.Port.BackupPort</class>'s <code>TaskRows</code> skips the rows whose <code>ReadOnly</code>
/// is set, the system tasks -> the four-built-ins assertion goes red.</p>
Method TestTheTasksReadHoldsTheFourBuiltInTasksFirst()
{
    Set tResult = ..Read(..#TASKS, .tHttp, .tFault)
    Do $$$AssertTrue($IsObject(tResult), "the read answers (" _ $Get(tHttp) _ ")")
    If '$IsObject(tResult) Quit
    Set tNames = ..Column(tResult, "Name")
    Do $$$AssertEquals($Piece(tNames, ",", 1, 4), ..#BUILTIN, "the four built-in tasks come first, in the vendor's order: " _ tNames)
    Set tRow = tResult.%Get("rows").%Get(0)
    Do $$$AssertEquals(tRow.%Get("SystemTask") _ "|" _ tRow.%Get("Type"), "1|Full", "a built-in task is a system task and reads its type")
    Do $$$AssertTrue(tRow.%IsDefined("LastRun") && tRow.%IsDefined("Status") && tRow.%IsDefined("Description") && tRow.%IsDefined("WritesFrozen"), "and carries its last run, status, description and whether writes are frozen")
    Do $$$AssertEquals(tResult.%Get("truncated") _ "|" _ tResult.%Get("banner"), "0|", "nothing is truncated and no banner is raised while writes run")
    Set tNamed = 0
    Set tIterator = tResult.%Get("rows").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tEach) {
        If $IsObject(tEach) && (tEach.%GetTypeOf("WritesFrozen") = "boolean") Set tNamed = tNamed + 1
    }
    Do $$$AssertEquals(tNamed, tResult.%Get("rows").%Size(), "every row names the write state as a boolean")
}

/// <p>AC1. History answers the harvested body's rows newest first, at most fifty, and reports truncation exactly when a fifty-first
/// entry exists.</p>
Method TestTheHistoryReadComesThroughTheBodyAndReportsTruncation()
{
    Set tResult = ..Read(..#HISTORY, .tHttp, .tFault)
    Do $$$AssertTrue($IsObject(tResult), "the read answers (" _ $Get(tHttp) _ ")")
    If '$IsObject(tResult) Quit
    Set tCount = ##class(OcuPilot.Test.BackupProbe).HistoryCount()
    Do $$$AssertEquals(tResult.%Get("rows").%Size(), $Select(tCount > 50: 50, 1: tCount), "it answers every entry up to fifty: " _ tCount _ " are recorded")
    Do $$$AssertEquals(''tResult.%Get("truncated"), ''(tCount > 50), "and truncated is true only when a fifty-first entry exists")
    If tResult.%Get("rows").%Size() > 0 Do $$$AssertTrue(tResult.%Get("rows").%Get(0).%IsDefined("Time") && tResult.%Get("rows").%Get(0).%IsDefined("Status"), "each row carries its time and status")
}

/// <p>AC1. Backup database list answers one row per database the vendor lists, with its directory.</p>
Method TestTheDatabaseListReadMatchesTheVendorList()
{
    Set tResult = ..Read(..#DATABASES, .tHttp, .tFault)
    Do $$$AssertTrue($IsObject(tResult), "the read answers (" _ $Get(tHttp) _ ")")
    If '$IsObject(tResult) Quit
    Do $$$AssertEquals(..Column(tResult, "Database"), ##class(OcuPilot.Test.BackupProbe).ListedNames(), "its rows are the vendor's list, in its order")
    If tResult.%Get("rows").%Size() > 0 Do $$$AssertNotEquals(tResult.%Get("rows").%Get(0).%Get("Directory"), "", "each row names its directory")
}

/// <p>AC1. The write state reads thawed with its limit, and a task or database the instance does not hold is absent: a task is matched
/// exactly, and the temporary database is never a database of the list.</p>
Method TestTheStatesNameWhatTheInstanceHoldsAndRefuseWhatItDoesNot()
{
    Kill tQuery
    Set tSC = $ClassMethod(..#PORT, "Invoke", "Writes", "GET", .tQuery, "", .tState, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the write state reads")
    Do $$$AssertEquals(tState.%Get("WriteState") _ "|" _ tState.%Get("LimitMax") _ "|" _ tState.%Get("Clustered"), "Thawed|600|0", "writes are thawed, the limit is 600 and this instance is not clustered")
    Set tQuery("name") = "FullDBList"
    Set tSC = $ClassMethod(..#PORT, "Invoke", "Tasks", "GET", .tQuery, "", .tTask, .tHttp, .tFault)
    Do $$$AssertEquals(tTask.%Get("Name") _ "|" _ tTask.%Get("AnyRunning"), "FullDBList|0", "a listed task reads, and nothing runs")
    For tName = "fulldblist", "NoSuchTask", "" {
        Set tQuery("name") = tName
        Set tSC = $ClassMethod(..#PORT, "Invoke", "Tasks", "GET", .tQuery, "", .tAbsent, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject(tFault): tFault.%Get("code"), 1: ""), "404|BACKUP.TASK.NOTFOUND", "'" _ tName _ "' is not a task, whatever its case")
    }
    Set tQuery("name") = "user"
    Set tSC = $ClassMethod(..#PORT, "Invoke", "Databases", "GET", .tQuery, "", .tDatabase, .tHttp, .tFault)
    Do $$$AssertEquals($Select($IsObject(tDatabase): tDatabase.%Get("Database"), 1: ""), "USER", "a database is matched without regard to case and answers its configured name")
    For tName = "iristemp", "NOSUCHDATABASE", "" {
        Set tQuery("name") = tName
        Set tSC = $ClassMethod(..#PORT, "Invoke", "Databases", "GET", .tQuery, "", .tAbsent, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject(tFault): tFault.%Get("code"), 1: ""), "404|BACKUP.DATABASE.NOTFOUND", "'" _ tName _ "' is not a database of the list")
    }
}

/// <p>AC1, AD-23. The harvested body is sent only the two fixed requests: <code>{"action":"listHistory"}</code> for the history and
/// <code>{"action":"run","taskName":&lt;name&gt;,"jobbackup":1}</code> for a run. Freeze, thaw and the list writes never reach it.</p>
/// <p>Mutation (Rule 19): <code>Run</code> sends <code>jobbackup</code> 0 -> the run assertion goes red.</p>
Method TestOnlyTheTwoFixedRequestsReachTheHarvestedBody()
{
    Do ..HoldAll()
    Kill tQuery
    Set tSC = $ClassMethod(..#SEAM, "Invoke", "History", "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    Do $$$AssertEquals($ClassMethod(..#RECORDER, "Requests"), "OcuPilot.Port.Harvest.Monitor.BackupManage {""action"":""listHistory""}", "the history sends the one listHistory request")
    Do $$$AssertEquals($Select($IsObject(tRows): tRows.%Get(0).%Get("Status"), 1: ""), "Completed", "and answers the rows the body returned")
    Do $ClassMethod(..#RECORDER, "Clear")
    Set tQuery("name") = "FullDBList"
    Set tSC = $ClassMethod(..#SEAM, "Invoke", "Tasks", "RUN", .tQuery, "", .tRun, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "a run of a listed task is sent (" _ $Select($IsObject(tFault): tFault.%Get("code"), 1: "") _ ")")
    Do $$$AssertEquals($ClassMethod(..#RECORDER, "Requests"), "OcuPilot.Port.Harvest.Monitor.BackupManage {""action"":""run"",""taskName"":""FullDBList"",""jobbackup"":1}", "the run sends the one run request, in the background")
    Do $ClassMethod(..#RECORDER, "Clear")
    Set tQuery("name") = "NoSuchTask"
    Set tSC = $ClassMethod(..#SEAM, "Invoke", "Tasks", "RUN", .tQuery, "", .tRun, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ $ClassMethod(..#RECORDER, "Requests"), "404|", "a task the list does not hold is refused and sends nothing")
    Kill tQuery
    Set tQuery("limit") = 5
    Do ..HoldAll()
    Do $ClassMethod(..#SEAM, "Cluster", 1)
    Set tSC = $ClassMethod(..#SEAM, "Invoke", "Writes", "FREEZE", .tQuery, "", .tFreeze, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject(tFault): tFault.%Get("code"), 1: "") _ "|" _ $ClassMethod(..#RECORDER, "Requests"), "409|BACKUP.FREEZE.UNBOUNDED|", "a freeze is refused where the limit cannot hold, and reaches no body")
}

/// <p>AC1, AD-51. The vendor's refusal #7309, fed to a freeze the rules let through, is answered 409 <code>BACKUP.RUNNING</code> with
/// nothing sent to the harvested body. It is the mapping the write test cannot pin, because a live backup's own suspension of writes
/// answers <code>BACKUP.FROZEN</code> at an unpredictable moment.</p>
/// <p>Mutation (Rule 19): <code>FreezeOrThaw</code> maps <code>CODEBACKUPRUNNING</code> to <code>FROZEN</code> -> the assertion goes red.</p>
Method TestTheVendorsRefusalOfAFreezeWhileABackupRunsIsAnswered409Running()
{
    Do ..HoldAll()
    Do $ClassMethod(..#SEAM, "VendorRefuses", $Parameter(..#PORT, "CODEBACKUPRUNNING"))
    Kill tQuery
    Set tQuery("limit") = 5
    Set tSC = $ClassMethod(..#SEAM, "Invoke", "Writes", "FREEZE", .tQuery, "", .tFreeze, .tHttp, .tFault)
    Do $$$AssertEquals($Parameter(..#PORT, "CODEBACKUPRUNNING"), 7309, "the code the port maps is the vendor's #7309")
    Do $$$AssertStatusNotOK(tSC, "the freeze fails")
    Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject(tFault): tFault.%Get("code"), 1: ""), "409|BACKUP.RUNNING", "#7309 is answered as a backup already running")
    Do $$$AssertEquals($ClassMethod(..#RECORDER, "Requests"), "", "and reaches no body")
}

/// <p>AC1. Every read is refused to a caller holding none of its pairs, naming the first, before any vendor call: the history's body is
/// not run, so it answers no rows.</p>
/// <p>Mutation (Rule 19): <code>Admit</code> answers OK without evaluating the pairs -> the denial assertions go red.</p>
Method TestEveryReadIsRefusedToACallerShortOfItsPairs()
{
    For tCase = $ListBuild("Tasks", "LIST"), $ListBuild("History", "LIST"), $ListBuild("Databases", "LIST"), $ListBuild("Writes", "GET"), $ListBuild("Tasks", "GET") {
        Kill tQuery
        Set tQuery("name") = "FullDBList"
        Set tSC = $ClassMethod(..#SEAM, "Invoke", $List(tCase, 1), $List(tCase, 2), .tQuery, "", .tRows, .tHttp, .tFault)
        Set tDetail = $Select($IsObject(tFault) && $IsObject(tFault.%Get("detail")): tFault.detail.%Get("failedPair"), 1: "")
        Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject(tFault): tFault.%Get("code"), 1: "") _ "|" _ tDetail _ "|" _ $IsObject(tRows), "403|AUTH.NOPRIVILEGE|%Admin_Operate:USE|0", $List(tCase, 1) _ " " _ $List(tCase, 2) _ " is refused naming the first pair and answers no rows")
    }
    Do $$$AssertEquals($ClassMethod(..#RECORDER, "Requests"), "", "and no harvested body ran")
    Set tSC = $ClassMethod(..#SEAM, "Rows", "Tasks", 10, .tRows, .tHttp, .tFault, .tCut)
    Do $$$AssertEquals(tHttp, 403, "the screens' own list call is gated too")
}

/// <p>The Gate row, AC1, AD-29. Every write is refused to a caller who holds the read pairs but not <code>%DB_IRISSYS:WRITE</code>,
/// naming that pair, before any vendor call or body, while the same caller's reads are admitted. The instance is read as clustered
/// and the targets are ones that hold no task or database, so a gate that wrongly admitted the call would still send nothing.</p>
/// <p>Mutation (Rule 19): <code>WRITEPAIRS</code> without <code>%DB_IRISSYS:WRITE</code> -> every write row goes red.</p>
Method TestEveryWriteIsRefusedToACallerWithoutTheWritePair()
{
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Admin_Operate", "USE")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_IRISSYS", "READ")
    Do $ClassMethod(..#SEAM, "Cluster", 1)
    Kill tQuery
    Set tSC = $ClassMethod(..#SEAM, "Invoke", "Tasks", "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 200, "a caller holding the two read pairs reads the tasks")
    For tCase = $ListBuild("Tasks", "RUN", "FullDBList"), $ListBuild("Writes", "FREEZE", ""), $ListBuild("Writes", "THAW", ""), $ListBuild("Databases", "ADD", "NOSUCHDATABASE"), $ListBuild("Databases", "REMOVE", "NOSUCHDATABASE") {
        Kill tQuery
        Set tQuery("limit") = 5
        If $List(tCase, 3) '= "" Set tQuery("name") = $List(tCase, 3)
        Set tSC = $ClassMethod(..#SEAM, "Invoke", $List(tCase, 1), $List(tCase, 2), .tQuery, "", .tOut, .tHttp, .tFault)
        Set tDetail = $Select($IsObject(tFault) && $IsObject(tFault.%Get("detail")): tFault.detail.%Get("failedPair"), 1: "")
        Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject(tFault): tFault.%Get("code"), 1: "") _ "|" _ tDetail, "403|AUTH.NOPRIVILEGE|%DB_IRISSYS:WRITE", $List(tCase, 2) _ " is refused naming the write pair")
    }
    Do $$$AssertEquals($ClassMethod(..#RECORDER, "Requests"), "", "and no harvested body ran")
}

/// <p>AC1, AD-5, AD-44, AD-51, AD-53. The three screens declare the classic Backup menu's three pages and its pairs (the write pair as the
/// screen's own), the backup read source and OS management's side-bar positions 23 to 25, and the five tools declare their screen
/// actions, their port, whether they are destructive and the consequence a card states.</p>
/// <p>Mutation (Rule 19): <code>BackupRun</code> declares <code>DESTRUCTIVE</code> 0 -> the destructive assertion goes red.</p>
Method TestTheScreensAndToolsDeclareTheirPagesPairsAndActions()
{
    For tCase = $ListBuild(..#TASKS, "os-management/backup-tasks", 23, "%cspapp.op.utilsysbackups", "backup-task", "run,freeze,thaw", "Tasks"), $ListBuild(..#HISTORY, "os-management/backup-history", 24, "%cspapp.op.utilsysbackuplogs", "", "", "History"), $ListBuild(..#DATABASES, "os-management/backup-databases", 25, "%cspapp.mgr.utilsysbackupdatabases", "backup-database", "add,removedatabase", "Databases") {
        Set tClass = $List(tCase, 1)
        Do $$$AssertStatusOK($ClassMethod(tClass, "DeclarationJson", .tDeclaration), tClass _ ": the declaration parses")
        Do $$$AssertEquals($ClassMethod(tClass, "Route") _ "|" _ $ClassMethod(tClass, "AreaKey") _ "|" _ $ClassMethod(tClass, "SideBarPosition"), $List(tCase, 2) _ "|os-management|" _ $List(tCase, 3), tClass _ ": its route, area and side-bar position")
        Do $$$AssertEquals($ClassMethod(tClass, "ClassicPage"), $List(tCase, 4), tClass _ ": its classic page")
        Do $$$AssertEquals(##class(%SYS.Portal.Resources).NormalizePage($ZConvert($List(tCase, 4), "O", "URL")), $List(tCase, 4), tClass _ ": which the portal's own resolver recognises, so a custom resource assigned to it is honoured (AD-44)")
        Do $$$AssertEquals($ClassMethod(tClass, "PrimaryEntityType") _ "|" _ $ListToString($ClassMethod(tClass, "RowActionIds")), $List(tCase, 5) _ "|" _ $List(tCase, 6), tClass _ ": its entity type and actions")
        Do $$$AssertEquals(tDeclaration.read.source.port _ "|" _ tDeclaration.read.source.endpoint _ "|" _ tDeclaration.read.source.type, "backup|" _ $List(tCase, 7) _ "|LIST", tClass _ ": it reads through the backup port")
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ReadProblem(tDeclaration), "", tClass _ ": its read is the declared grammar")
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).BannerProblem(tDeclaration), "", tClass _ ": and its banner, if any")
        Do $$$AssertEquals($ListToString($List($ClassMethod(tClass, "OwnPrivilegePairs"), 1), ","), "%DB_IRISSYS,WRITE", tClass _ ": the write pair is the screen's own")
        Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(tClass, .tResolved)
        Do $$$AssertTrue($ListFind(tPairs, $ListBuild("%Admin_Operate", "USE")) && $ListFind(tPairs, $ListBuild("%DB_IRISSYS", "READ")) && $ListFind(tPairs, $ListBuild("%DB_IRISSYS", "WRITE")), tClass _ ": it requires the classic Backup menu's pairs")
    }
    For tCase = $ListBuild("BackupRun", "osmgmt.backuptasks.run", "run", 1, "BACKUP.RUN"), $ListBuild("BackupFreeze", "osmgmt.backuptasks.freeze", "freeze", 0, "BACKUP.FREEZE"), $ListBuild("BackupThaw", "osmgmt.backuptasks.thaw", "thaw", 0, ""), $ListBuild("BackupDatabaseAdd", "osmgmt.backupdatabases.add", "add", 0, ""), $ListBuild("BackupDatabaseRemove", "osmgmt.backupdatabases.remove", "removedatabase", 0, "") {
        Set tTool = "OcuPilot.Screen.Tool." _ $List(tCase, 1)
        Do $$$AssertEquals($Parameter(tTool, "TOOLNAME") _ "|" _ $ListToString($ClassMethod(tTool, "ScreenActionIds")) _ "|" _ $ClassMethod(tTool, "PortClass"), $List(tCase, 2) _ "|" _ $List(tCase, 3) _ "|" _ ..#PORT, $List(tCase, 1) _ ": its name, its screen action and its port")
        Do $$$AssertEquals(''$ClassMethod(tTool, "Destructive") _ "|" _ $Select(##class(%Dictionary.CompiledMethod).%ExistsId(tTool _ "||Consequence"): $ClassMethod(tTool, "Consequence", {}), 1: ""), $List(tCase, 4) _ "|" _ $List(tCase, 5), $List(tCase, 1) _ ": whether it is destructive and the consequence its card states")
        Do $$$AssertEquals(''$ClassMethod(tTool, "SendsBody"), 0, $List(tCase, 1) _ ": it sends no body (AD-51)")
    }
    Do $$$AssertEquals($ListToString(##class(OcuPilot.Screen.Tool.BackupRun).PrivilegePairs(.tResolved), "|"), $ListToString(##class(OcuPilot.Screen.Gate).WithClassicPages(##class(OcuPilot.Screen.Gate).RequiredPairs(..#TASKS), "%cspapp.op.utilsysbackup"), "|"), "a run requires its screen's pairs and the custom resource of the classic page that starts a backup")
}

/// <p>AC2. The five keys ship disabled in the baseline, and with none stored the agent's call for each is refused
/// <code>GOVERNANCE.DISABLED</code> at dispatch before anything is minted.</p>
/// <p>Mutation (Rule 19): <code>osmgmt.backuptasks.freeze</code> set <code>true</code> in
/// <class>OcuPilot.Kernel.Governance.Baseline</class> -> the baseline assertion goes red for that key.</p>
Method TestTheFiveKeysShipDisabledAndTheAgentIsRefusedAtDispatch()
{
    For tI = 1:1:$Length(..#KEYS, ",") {
        Set tKey = $Piece(..#KEYS, ",", tI)
        Do $$$AssertEquals(##class(OcuPilot.Test.Governance).Resolved(tKey), "0|baseline", tKey _ " ships disabled by the baseline")
        Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurnKey)
        Do $$$AssertStatusOK(tSC, "a probe turn is seeded")
        If $$$ISERR(tSC) Continue
        Set tUse = {"type": "tool_use", "id": "toolu_backup", "input": {"Name": "FullDBList", "rationale": "probe", "expectedImpact": "probe"}}
        Do tUse.%Set("name", ##class(OcuPilot.Screen.Tool.Registry).WireName(tKey), "string")
        Do ##class(OcuPilot.Kernel.Proposal.Caller).Set(tTurnKey)
        Set tSC = ##class(OcuPilot.Kernel.Agent.Dispatch).Answer(tTurnKey, $Username, "", [(tUse)], ..#LIMITS, .tResults, .tNames, 0, 0, .tDetails)
        Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
        Set tAnswer = ""
        If $IsObject($Get(tResults)) && (tResults.%Size() = 1) Set tAnswer = $Select(tResults.%Get(0).%Get("is_error"): 1, 1: 0) _ "|" _ tResults.%Get(0).%Get("content")
        Do $$$AssertEquals(tAnswer, "1|{""code"":""GOVERNANCE.DISABLED""}", tKey _ ": the agent's call is refused by the governance gate and nothing is minted")
        Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurnKey)
    }
}

}

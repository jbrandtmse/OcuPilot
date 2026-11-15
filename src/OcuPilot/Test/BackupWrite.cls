/// <p>Pins Story 21.2's five writes on both callers (AC1, AC2, AC3; AD-26, AD-51, AD-53, AD-58): Backup tasks' Run, Freeze writes and Thaw
/// writes and Backup database list's Add database and Remove, each through the screen's own action route
/// (<class>OcuPilot.Test.EcpActionFixture</class>) and through the agent's mint and confirm
/// (<class>OcuPilot.Test.LicenseProbe</class>), against the real instance. A freeze carries its limit to the instance, which resumes
/// writes by itself within the limit and a measured second or two; the refusals of the matrix are observed at the screen's route, at
/// the mint and at the port, with nothing sent.</p>
/// <p>The run test runs a task this class defines over one probe database: the built-in tasks write to <code>/Backup</code>, which
/// the instance may not be able to create (measured on the throwaway), so a run of one is no run of a backup.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, and <parameter>ARMINGVARIABLE</parameter> reading
/// <code>1</code>, because the class freezes database writes, runs a backup, changes the backup database list and sets the governance
/// policy. After each test writes are thawed, the backup list is as the test found it and every probe object is removed by exact name
/// (<class>OcuPilot.Test.BackupProbe</class>).</p>
Class OcuPilot.Test.BackupWrite Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms the backup writes, set by <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_BACKUP_CONTROL";

Parameter PORT = "OcuPilot.Port.BackupPort";

Parameter PROBE = "OcuPilot.Test.BackupProbe";

Parameter ACTION = "OcuPilot.Test.EcpActionFixture";

/// <p>The class whose <code>Verdict</code> and <code>Parsed</code> read an action's answer.</p>
Parameter VERDICT = "OcuPilot.Test.EcpDataServerWrite";

Parameter AGENT = "OcuPilot.Test.LicenseProbe";

Parameter TASKSCREEN = "osmgmt.backuptasks";

Parameter LISTSCREEN = "osmgmt.backupdatabases";

Parameter KEYS = "osmgmt.backuptasks.run,osmgmt.backuptasks.freeze,osmgmt.backuptasks.thaw,osmgmt.backupdatabases.add,osmgmt.backupdatabases.remove";

/// <p>Seconds past a freeze's limit the instance is given to resume writes: it was measured resuming within the limit, polled each second.</p>
Parameter SLACK = 6;

/// <p>The governance policy and the backup list as they stood before the class ran.</p>
Property PreparedPolicy [ MultiDimensional ];

Property PreparedPolicyTaken As %Boolean [ InitialExpression = 0 ];

Property PreparedList As %String(MAXLEN = "") [ InitialExpression = "" ];

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.BackupWrite freezes database writes, runs a backup and changes the backup database list on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed.")
    }
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tRows)
    If $$$ISERR(tSC) Quit tSC
    Merge ..PreparedPolicy = tRows
    Set ..PreparedPolicyTaken = 1
    Do $ClassMethod(..#PROBE, "Thaw")
    Set ..PreparedList = $ClassMethod(..#PROBE, "ListedNames")
    Do $ClassMethod(..#PROBE, "Remove")
    Quit $$$OK
}

/// <p>Every test waits for the previous test's backup to finish, thaws, enables the five keys over the snapshot and starts from the list it found.</p>
Method OnBeforeOneTest() As %Status
{
    ; The confirm fixture's port is the shipped backup port, so the confirm reads and writes the instance.
    Set ^||OcuPilotDatabaseWritePort = ..#PORT
    Do $ClassMethod(..#PROBE, "WaitForIdle", 120)
    Do $ClassMethod(..#PROBE, "WaitForSettled", 15)
    Do $ClassMethod(..#PROBE, "Thaw")
    Kill tSettings
    For tI = 1:1:$Length(..#KEYS, ",") Set tSettings($Piece(..#KEYS, ",", tI)) = "enabled"
    Quit ##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings)
}

Method OnAfterOneTest() As %Status
{
    Kill ^||OcuPilotDatabaseWritePort
    Do $ClassMethod(..#PROBE, "RestoreHistory")
    Do ##class(OcuPilot.Test.BackupGateSeam).Reset()
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do $$$AssertEquals($ClassMethod(..#PROBE, "WaitForIdle", 120), 1, "no probe backup is still running")
    Do $ClassMethod(..#PROBE, "WaitForSettled", 15)
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Thaw"), 0, "writes are thawed after the test")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SetList", ..PreparedList), "the backup list is put back")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "ListedNames"), ..PreparedList, "and reads as it was found")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Remove"), "", "every probe object is removed")
    Kill tRows
    Merge tRows = ..PreparedPolicy
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows), "the governance policy is restored")
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tSeeded)
    Quit $$$OK
}

Method OnAfterAllTests() As %Status
{
    Kill ^||OcuPilotDatabaseWritePort
    Do $ClassMethod(..#PROBE, "Thaw")
    If '..PreparedPolicyTaken Quit $$$OK
    Merge tRows = ..PreparedPolicy
    Quit ##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows)
}

/// <p>The screen action <var>pAction</var> on <var>pId</var> of screen <var>pScreen</var>, through the action fixture, with
/// <var>pValues</var>; the answer's parsed envelope in <var>pAnswer</var>, answering the HTTP status.</p>
ClassMethod Act(pScreen As %String, pAction As %String, pId As %String, pValues As %DynamicObject = "", Output pAnswer As %DynamicObject) As %Integer
{
    Set tBody = {"action": (pAction)}
    Do tBody.%Set("id", pId, "string")
    If $IsObject(pValues) Do tBody.%Set("values", pValues)
    Set tSC = $ClassMethod(..#ACTION, "Act", pScreen, tBody, .tJson, .tStatus)
    Set pAnswer = $ClassMethod(..#VERDICT, "Parsed", tJson)
    Quit tStatus
}

/// <p>The refusal code an answer carries, or <code>""</code>.</p>
ClassMethod Code(pAnswer As %DynamicObject) As %String
{
    Quit $Select($IsObject(pAnswer): pAnswer.%Get("code"), 1: "")
}

/// <p>Whether <var>pName</var> is on the backup database list now.</p>
ClassMethod Listed(pName As %String) As %Boolean
{
    Quit ''$Find("," _ $ClassMethod(..#PROBE, "ListedNames") _ ",", "," _ pName _ ",")
}

/// <p>The banner key the Backup tasks read answers now, or <code>""</code>.</p>
ClassMethod TasksBanner() As %String
{
    Set tSC = ##class(OcuPilot.Screen.Read).Execute("OcuPilot.Screen.Descriptor.BackupTaskList", "", .tResult, .tHttp, .tFault)
    Quit $Select($$$ISOK(tSC) && $IsObject(tResult): tResult.%Get("banner"), 1: "(no read: " _ $Get(tHttp) _ ")")
}

/// <p>Whether writes read frozen through the port.</p>
ClassMethod Frozen() As %Boolean
{
    Kill tQuery
    Set tSC = $ClassMethod(..#PORT, "Invoke", "Writes", "GET", .tQuery, "", .tState, .tHttp, .tFault)
    Quit $IsObject($Get(tState)) && (tState.%Get("WriteState") = "Frozen")
}

/// <p>Mint <var>pTool</var> for <var>pName</var> with <var>pArgs</var> and confirm it; answers <code>http code</code> and the confirm's
/// answer in <var>pResult</var>, or <code>refused: &lt;problem&gt;</code> when the mint refused.</p>
ClassMethod Agent(pTool As %String, pName As %String, pArgs As %DynamicObject, Output pResult As %DynamicObject) As %String
{
    Set tSC = $ClassMethod(..#AGENT, "Mint", pTool, pName, pArgs, .tProposal, .tHttp, .tProblem)
    If '$IsObject($Get(tProposal)) Quit "refused: " _ $Get(tProblem)
    Quit $ClassMethod(..#AGENT, "Confirm", tProposal, .pResult)
}

/// <p>Wait up to <var>pSeconds</var> for writes to read thawed; the seconds it took, or -1.</p>
ClassMethod WaitForThaw(pSeconds As %Integer) As %Numeric
{
    Set tStart = $ZHorolog
    While ($ZHorolog - tStart) < pSeconds {
        If '..Frozen() Quit
        Hang 0.25
    }
    Quit $Select(..Frozen(): -1, 1: $ZHorolog - tStart)
}

/// <p><b>AC1, AC2.</b> A freeze and a thaw each succeed on both callers: the screen's actions on the literal <code>SYSTEM</code> and the
/// agent's confirmed proposals, each with a read-back reading <code>nothingSent</code>, and the write state follows.</p>
Method TestAFreezeAndAThawSucceedOnBothCallers()
{
    Set tStatus = ..Act(..#TASKSCREEN, "freeze", "SYSTEM", {"limit": "60"}, .tAnswer)
    Do $$$AssertEquals(tStatus _ "|" _ ..Frozen() _ "|" _ $ClassMethod(..#VERDICT, "Verdict", tAnswer), "200|1|nothingSent", "the screen's freeze freezes writes: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: ""))
    Do $$$AssertEquals(..TasksBanner(), "backupFrozenBanner", "the Backup tasks read raises the frozen banner while writes are frozen")
    Do $$$AssertEquals(..Act(..#TASKSCREEN, "thaw", "SYSTEM", "", .tAnswer) _ "|" _ ..Frozen(), "200|0", "the screen's thaw resumes them")
    Do $$$AssertEquals(..TasksBanner(), "", "and the banner is gone once they are thawed")
    Set tOutcome = ..Agent("OcuPilot.Screen.Tool.BackupFreeze", "SYSTEM", {"Name": "SYSTEM", "limit": 60}, .tResult)
    Do $$$AssertEquals(tOutcome _ "|" _ ..Frozen() _ "|" _ $ClassMethod(..#VERDICT, "Verdict", tResult), "200 |1|nothingSent", "the agent's confirmed freeze freezes writes: " _ tOutcome)
    Set tOutcome = ..Agent("OcuPilot.Screen.Tool.BackupThaw", "SYSTEM", {"Name": "SYSTEM"}, .tResult)
    Do $$$AssertEquals(tOutcome _ "|" _ ..Frozen(), "200 |0", "and its confirmed thaw resumes them: " _ tOutcome)
}

/// <p><b>AC1.</b> The history answers at most fifty rows, newest first, and reports truncation only when a fifty-first entry exists: with
/// fifty entries seeded it does not, with fifty-one it does. The history the instance held is put back after each test.</p>
/// <p>Mutation (Rule 19): <code>MoreHistory</code> always answers 0 -> the fifty-one case goes red.</p>
Method TestTheHistoryReportsTruncationOnlyPastFifty()
{
    For tCount = 50, 51 {
        Do $ClassMethod(..#PROBE, "SeedHistory", tCount)
        Set tSC = ##class(OcuPilot.Screen.Read).Execute("OcuPilot.Screen.Descriptor.BackupHistoryList", "", .tResult, .tHttp, .tFault)
        Do $$$AssertStatusOK(tSC, "the history read answers with " _ tCount _ " entries")
        If $$$ISERR(tSC) || '$IsObject($Get(tResult)) Continue
        Do $$$AssertEquals(tResult.%Get("rows").%Size() _ "|" _ ''tResult.%Get("truncated"), "50|" _ (tCount = 51), "with " _ tCount _ " entries it answers fifty rows and truncated reads " _ (tCount = 51))
        Do $$$AssertEquals(tResult.%Get("rows").%Get(0).%Get("Description"), "seeded " _ tCount, "newest first")
    }
    Do $ClassMethod(..#PROBE, "RestoreHistory")
}

/// <p><b>AC3.</b> A freeze's limit reaches the instance: on each caller, with a limit of 5, writes read thawed again without a thaw within
/// the limit and <parameter>SLACK</parameter> seconds.</p>
/// <p>Mutation (Rule 19): <code>SuspendCall</code> passes <code>WDSuspendLimit</code> 0 -> writes stay frozen and both resume
/// assertions go red; the teardown thaws.</p>
Method TestAFreezeResumesWithoutAThawOnBothCallers()
{
    Set tStatus = ..Act(..#TASKSCREEN, "freeze", "SYSTEM", {"limit": "5"}, .tAnswer)
    Do $$$AssertEquals(tStatus _ "|" _ ..Frozen(), "200|1", "the screen's freeze with a limit of 5 freezes writes")
    Set tTook = ..WaitForThaw(5 + ..#SLACK)
    Do $$$AssertTrue(tTook >= 0, "writes resume by themselves within the limit and " _ ..#SLACK _ " seconds (" _ tTook _ " s)")
    Do $$$AssertEquals(..Agent("OcuPilot.Screen.Tool.BackupFreeze", "SYSTEM", {"Name": "SYSTEM", "limit": 5}, .tResult) _ "|" _ ..Frozen(), "200 |1", "the agent's freeze with a limit of 5 freezes writes")
    Set tTook = ..WaitForThaw(5 + ..#SLACK)
    Do $$$AssertTrue(tTook >= 0, "and they resume by themselves too (" _ tTook _ " s)")
}

/// <p>The refusals of the matrix, each with nothing frozen or thawed: a limit that is missing, 0, 601 or text at the port, the screen and
/// the mint; a freeze while frozen; a thaw while thawed; and, through a seam that reads the instance as clustered, a freeze whose limit
/// cannot hold.</p>
Method TestTheFreezeAndThawRefusalsSendNothing()
{
    For tLimit = "", 0, 601, "x", "007" {
        Kill tQuery
        If tLimit '= "" Set tQuery("limit") = tLimit
        Set tSC = $ClassMethod(..#PORT, "Invoke", "Writes", "FREEZE", .tQuery, "", .tOut, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject(tFault): tFault.%Get("code"), 1: "") _ "|" _ ..Frozen(), "400|BACKUP.FREEZE.LIMIT|0", "the port refuses limit '" _ tLimit _ "' and freezes nothing")
        If tLimit = "" Continue
        Set tValues = {}
        Do tValues.%Set("limit", tLimit, "string")
        Set tStatus = ..Act(..#TASKSCREEN, "freeze", "SYSTEM", tValues, .tAnswer)
        Do $$$AssertEquals(tStatus _ "|" _ ..Code(tAnswer) _ "|" _ ..Frozen(), "400|BACKUP.FREEZE.LIMIT|0", "the screen refuses limit '" _ tLimit _ "'")
        Do $$$AssertEquals(..Agent("OcuPilot.Screen.Tool.BackupFreeze", "SYSTEM", {"Name": "SYSTEM", "limit": (tLimit)}, .tResult) [ "refused: ", 1, "the mint refuses limit '" _ tLimit _ "'")
    }
    Do $$$AssertEquals(..Agent("OcuPilot.Screen.Tool.BackupFreeze", "SYSTEM", {"Name": "SYSTEM"}, .tResult) [ "refused: ", 1, "the mint refuses a freeze with no limit")
    Kill tQuery
    Set tQuery("limit") = 60
    Set tSC = $ClassMethod(..#PORT, "Invoke", "Writes", "FREEZE", .tQuery, "", .tOut, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ ..Frozen(), "200|1", "a freeze with a limit of 60 freezes writes")
    Set tStatus = ..Act(..#TASKSCREEN, "freeze", "SYSTEM", {"limit": "30"}, .tAnswer)
    Do $$$AssertEquals(tStatus _ "|" _ ..Code(tAnswer), "409|BACKUP.FROZEN", "a second freeze is refused at the screen")
    Do $$$AssertEquals(..Agent("OcuPilot.Screen.Tool.BackupFreeze", "SYSTEM", {"Name": "SYSTEM", "limit": 30}, .tResult), "refused: Database writes are already frozen.", "and at the mint")
    Do $ClassMethod(..#PROBE, "Thaw")
    Set tStatus = ..Act(..#TASKSCREEN, "thaw", "SYSTEM", "", .tAnswer)
    Do $$$AssertEquals(tStatus _ "|" _ ..Code(tAnswer), "409|BACKUP.NOTFROZEN", "a thaw of thawed writes is refused at the screen")
    Do $$$AssertEquals(..Agent("OcuPilot.Screen.Tool.BackupThaw", "SYSTEM", {"Name": "SYSTEM"}, .tResult), "refused: Database writes are not frozen.", "and at the mint")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Admin_Operate", "USE")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_IRISSYS", "READ")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_IRISSYS", "WRITE")
    Do ##class(OcuPilot.Test.BackupGateSeam).Cluster(1)
    Kill tQuery
    Set tQuery("limit") = 5
    Set tSC = ##class(OcuPilot.Test.BackupGateSeam).Invoke("Writes", "FREEZE", .tQuery, "", .tOut, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject(tFault): tFault.%Get("code"), 1: "") _ "|" _ ..Frozen(), "409|BACKUP.FREEZE.UNBOUNDED|0", "where the instance would ignore the limit the freeze is refused before any vendor call (seam: no clustered system to test on)")
    Do ##class(OcuPilot.Test.BackupGateSeam).Reset()
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
}

/// <p><b>AC1.</b> A run starts the probe task in the background on both callers, with a read-back reading <code>nothingSent</code>, and the
/// task's status leaves its prior value and a history row appears. A task the list does not hold is refused 404, and a run while a task
/// runs is refused 409 with nothing started.</p>
/// <p>Mutation (Rule 19): <class>OcuPilot.Area.OsMgmt.BackupRules</class> never answers <code>BACKUP.RUNNING</code> -> the run-while-running
/// rows go red.</p>
Method TestARunStartsTheTaskOnBothCallers()
{
    Set tTask = $Parameter(..#PROBE, "TASK")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Create"), "the probe database and task are created")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SetList", $Parameter(..#PROBE, "DATABASE")), "and the list holds only the probe database")
    Set tBefore = $ClassMethod(..#PROBE, "HistoryCount")
    Set tPrior = $ClassMethod(..#PROBE, "TaskStatus")
    Set tStatus = ..Act(..#TASKSCREEN, "run", tTask, "", .tAnswer)
    Do $$$AssertEquals(tStatus _ "|" _ $ClassMethod(..#VERDICT, "Verdict", tAnswer), "200|nothingSent", "the screen's run starts the task: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: ""))
    Do $$$AssertEquals($ClassMethod(..#PROBE, "WaitForStatus", "Completed", 120), 1, "its status leaves " _ $Select(tPrior = "": "(none)", 1: tPrior) _ " and reads Completed")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "HistoryCount"), tBefore + 1, "and a history row appears")
    Set tOutcome = ..Agent("OcuPilot.Screen.Tool.BackupRun", tTask, {"Name": (tTask)}, .tResult)
    Do $$$AssertEquals(tOutcome _ "|" _ $ClassMethod(..#VERDICT, "Verdict", tResult), "200 |nothingSent", "the agent's confirmed run starts it too: " _ tOutcome)
    Do $$$AssertEquals($ClassMethod(..#PROBE, "WaitForIdle", 120), 1, "it completes")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "HistoryCount"), tBefore + 2, "and a second history row appears")
    Set tStatus = ..Act(..#TASKSCREEN, "run", "NoSuchTask", "", .tAnswer)
    Do $$$AssertEquals(tStatus, 404, "a task the list does not hold is refused at the screen")
    Do $$$AssertEquals(..Agent("OcuPilot.Screen.Tool.BackupRun", "NoSuchTask", {"Name": "NoSuchTask"}, .tResult), "refused: 'NoSuchTask' is not present on this instance", "and at the mint, which reads the target first")
    Do $ClassMethod(..#PROBE, "Start")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "WaitForStatus", "Running", 20), 1, "a task is running")
    Set tStatus = ..Act(..#TASKSCREEN, "run", tTask, "", .tAnswer)
    Do $$$AssertEquals(tStatus _ "|" _ ..Code(tAnswer), "409|BACKUP.RUNNING", "a run while a task runs is refused at the screen")
    Do $$$AssertEquals(..Agent("OcuPilot.Screen.Tool.BackupRun", tTask, {"Name": (tTask)}, .tResult), "refused: A backup is already running.", "and at the mint")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "WaitForIdle", 120), 1, "it completes")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "HistoryCount"), tBefore + 3, "and only the run that started added a row")
}

/// <p><b>AC1.</b> Add database and Remove round-trip a probe database on both callers: the list read holds it after the add and no longer
/// after the remove. A database the instance does not hold and the temporary database are refused 404, a database already listed or not
/// listed 409.</p>
/// <p>Mutation (Rule 19): <code>ChangeList</code> sends <code>RemoveDatabaseFromList</code> for an add -> the add rows go red.</p>
Method TestAddAndRemoveRoundTripAProbeDatabaseOnBothCallers()
{
    Set tDatabase = $Parameter(..#PROBE, "DATABASE")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Create"), "the probe database is created, off the list")
    Do $$$AssertEquals(..Listed(tDatabase), 0, "it is not listed")
    Set tStatus = ..Act(..#LISTSCREEN, "add", tDatabase, "", .tAnswer)
    Do $$$AssertEquals(tStatus _ "|" _ $ClassMethod(..#VERDICT, "Verdict", tAnswer), "200|nothingSent", "the screen's add lists it: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: ""))
    Do $$$AssertEquals(..Listed(tDatabase), 1, "the list now holds it")
    Set tStatus = ..Act(..#LISTSCREEN, "add", tDatabase, "", .tAnswer)
    Do $$$AssertEquals(tStatus _ "|" _ ..Code(tAnswer), "409|BACKUP.LIST.CONFLICT", "a second add is refused")
    Set tStatus = ..Act(..#LISTSCREEN, "removedatabase", tDatabase, "", .tAnswer)
    Do $$$AssertEquals(tStatus _ "|" _ $ClassMethod(..#VERDICT, "Verdict", tAnswer), "200|nothingSent", "the screen's remove unlists it")
    Do $$$AssertEquals(..Listed(tDatabase), 0, "the list no longer holds it")
    Set tStatus = ..Act(..#LISTSCREEN, "removedatabase", tDatabase, "", .tAnswer)
    Do $$$AssertEquals(tStatus _ "|" _ ..Code(tAnswer), "409|BACKUP.LIST.CONFLICT", "a second remove is refused")
    Do $$$AssertEquals(..Agent("OcuPilot.Screen.Tool.BackupDatabaseAdd", tDatabase, {"Name": (tDatabase)}, .tResult) _ "|" _ $ClassMethod(..#VERDICT, "Verdict", tResult), "200 |nothingSent", "the agent's confirmed add lists it")
    Do $$$AssertEquals(..Agent("OcuPilot.Screen.Tool.BackupDatabaseAdd", tDatabase, {"Name": (tDatabase)}, .tResult), "refused: The backup list already reflects that change.", "and a second add is refused at the mint")
    Do $$$AssertEquals(..Agent("OcuPilot.Screen.Tool.BackupDatabaseRemove", tDatabase, {"Name": (tDatabase)}, .tResult) _ "|" _ $ClassMethod(..#VERDICT, "Verdict", tResult), "200 |nothingSent", "the agent's confirmed remove unlists it")
    Do $$$AssertEquals(..Agent("OcuPilot.Screen.Tool.BackupDatabaseRemove", tDatabase, {"Name": (tDatabase)}, .tResult), "refused: The backup list already reflects that change.", "and a second remove is refused at the mint")
    For tName = "NOSUCHDATABASE", "IRISTEMP" {
        Set tStatus = ..Act(..#LISTSCREEN, "add", tName, "", .tAnswer)
        Do $$$AssertEquals(tStatus _ "|" _ ..Code(tAnswer), "404|BACKUP.DATABASE.NOTFOUND", tName _ " is refused at the screen")
        Do $$$AssertEquals(..Agent("OcuPilot.Screen.Tool.BackupDatabaseAdd", tName, {"Name": (tName)}, .tResult), "refused: '" _ tName _ "' is not present on this instance", "and at the mint, which reads the target first")
    }
}

/// <p><b>AC2.</b> With the key enabled the agent's call for a freeze is dispatched, mints a proposal and its confirm freezes writes once,
/// with a read-back; the proposal's token is spent, so a second confirm is refused and freezes nothing more. Set back to the baseline
/// the same call is refused at dispatch.</p>
Method TestWithTheKeyEnabledTheSameProposalMintsAndConfirmsOnce()
{
    Do $$$AssertEquals(..Dispatched("osmgmt.backuptasks.freeze", {"Name": "SYSTEM", "limit": 30, "rationale": "probe", "expectedImpact": "probe"}, .tProposalId, .tTurnKey) _ "|" _ (tProposalId '= ""), "minted|1", "the enabled key lets the call mint a proposal")
    Set tSC = ##class(OcuPilot.Test.DatabaseConfirm).Confirm(tProposalId, "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertEquals($$$ISOK(tSC) _ "|" _ $Get(tCode) _ "|" _ ..Frozen() _ "|" _ $ClassMethod(..#VERDICT, "Verdict", tResult), "1||1|nothingSent", "its confirm freezes writes once, with a read-back: " _ $Get(tCode))
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditMarker).WriteRow(tTurnKey, .tRow), 1, "one write-kind ledger row records it")
    Do $$$AssertEquals($Get(tRow("AuditMarked")), $Parameter("OcuPilot.Kernel.State.Ledger", "MARKEDYES"), "and the agent's audit marker landed on it")
    Do $ClassMethod(..#PROBE, "Thaw")
    Set tSC = ##class(OcuPilot.Test.DatabaseConfirm).Confirm(tProposalId, "", $Username, .tResult2, .tHttp2, .tCode2, .tDetail2)
    Do $$$AssertEquals($$$ISERR(tSC) _ "|" _ ..Frozen(), "1|0", "a second confirm of the same proposal is refused and freezes nothing")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Clear(), "the policy is back at the baseline")
    Do $$$AssertEquals(..Dispatched("osmgmt.backuptasks.freeze", {"Name": "SYSTEM", "limit": 30, "rationale": "probe", "expectedImpact": "probe"}, .tNone), "refused", "and the same call is refused at dispatch")
}

/// <p>The agent's dispatch of <var>pKey</var> with <var>pInput</var>: <code>minted</code> with the proposal id in
/// <var>pProposalId</var> and the turn's key in <var>pTurnKey</var>, or <code>refused</code>.</p>
ClassMethod Dispatched(pKey As %String, pInput As %DynamicObject, Output pProposalId As %String, Output pTurnKey As %String) As %String
{
    Set pProposalId = ""
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurnKey)
    Set pTurnKey = $Get(tTurnKey)
    If $$$ISERR(tSC) Quit "no turn"
    Set tUse = {"type": "tool_use", "id": "toolu_backup"}
    Do tUse.%Set("name", ##class(OcuPilot.Screen.Tool.Registry).WireName(pKey), "string")
    Do tUse.%Set("input", pInput)
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Set(tTurnKey)
    Set tSC = ##class(OcuPilot.Kernel.Agent.Dispatch).Answer(tTurnKey, $Username, "", [(tUse)], "OcuPilot.Kernel.Agent.Limits", .tResults, .tNames, 0, 0, .tDetails)
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Set tContent = $Select($IsObject($Get(tResults)) && (tResults.%Size() = 1): tResults.%Get(0).%Get("content"), 1: "")
    Set tParsed = ##class(OcuPilot.Test.LicenseKey).Parsed(tContent)
    If $IsObject(tParsed) Set pProposalId = tParsed.%Get("proposalId")
    Quit $Select(pProposalId '= "": "minted", 1: "refused")
}

}

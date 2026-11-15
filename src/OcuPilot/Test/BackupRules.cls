/// <p>Pins every refusal row of Story 21.2's matrix as <class>OcuPilot.Area.OsMgmt.BackupRules</class> judges it (AC1, AC3; AD-51,
/// AD-55): the freeze's limit, writes already frozen, the instance that would ignore the limit, a thaw of writes that are not frozen, a
/// run while any task runs or writes are frozen, a list change the list already reflects, and the one sentence each code carries. The
/// rules are pure over the target's state; only the mint test reads the instance, through the tools' own port.</p>
/// <p><b>Live-safe.</b> It writes nothing. The mint test needs database writes not frozen and no task named <code>NoSuchTask</code> or
/// database named <code>NOSUCHDATABASE</code>.</p>
Class OcuPilot.Test.BackupRules Extends %UnitTest.TestCase
{

Parameter RULES = "OcuPilot.Area.OsMgmt.BackupRules";

Parameter ERROR = "OcuPilot.Api.BackupError";

/// <p>The code the rules answer for <var>pType</var> against the state JSON <var>pState</var> and the limit <var>pLimit</var>.</p>
ClassMethod Verdict(pType As %String, pState As %String, pLimit As %String = "") As %String
{
    Kill tQuery
    If pLimit '= "" Set tQuery("limit") = pLimit
    Quit $ClassMethod(..#RULES, "Code", pType, ##class(%DynamicObject).%FromJSON(pState), .tQuery)
}

/// <p>AC3. A suspend limit is a whole number of seconds from 1 to 600, written plainly: a missing limit, 0, 601, text, a fraction, a
/// sign or a leading zero is <code>BACKUP.FREEZE.LIMIT</code>, and 1 and 600 hold.</p>
/// <p>Mutation (Rule 19): the port's <code>FREEZELIMITMAX</code> 6000 -> the 601 row goes red.</p>
Method TestAFreezeNeedsALimitFromOneToSixHundred()
{
    Set tThawed = "{""WriteState"":""Thawed"",""Clustered"":false}"
    For tLimit = "", 0, 601, "x", "5.5", "-1", "+5", "007", 1000, " 5" {
        Set tText = $Select(tLimit = "": "(missing)", 1: tLimit)
        Do $$$AssertEquals(..Verdict("FREEZE", tThawed, tLimit), "BACKUP.FREEZE.LIMIT", "limit " _ tText _ " is refused")
    }
    For tLimit = 1, 5, 600 {
        Do $$$AssertEquals(..Verdict("FREEZE", tThawed, tLimit), "", "limit " _ tLimit _ " holds")
    }
    Do $$$AssertEquals($Parameter("OcuPilot.Port.BackupPort", "FREEZELIMITMAX"), 600, "the port's bound is 600 seconds")
}

/// <p>AC1. A freeze is refused while writes are frozen and where the instance would ignore its limit, a bad limit first; a thaw is refused
/// while they are not frozen.</p>
Method TestAFreezeAndAThawAreJudgedAgainstTheWriteState()
{
    Do $$$AssertEquals(..Verdict("FREEZE", "{""WriteState"":""Frozen"",""Clustered"":false}", 5), "BACKUP.FROZEN", "a freeze while frozen")
    Do $$$AssertEquals(..Verdict("FREEZE", "{""WriteState"":""Thawed"",""Clustered"":true}", 5), "BACKUP.FREEZE.UNBOUNDED", "a freeze where the limit cannot hold")
    Do $$$AssertEquals(..Verdict("FREEZE", "{""WriteState"":""Frozen"",""Clustered"":true}", 5), "BACKUP.FROZEN", "frozen is judged before the clustered system")
    Do $$$AssertEquals(..Verdict("FREEZE", "{""WriteState"":""Frozen"",""Clustered"":true}", 0), "BACKUP.FREEZE.LIMIT", "and a bad limit before both")
    Do $$$AssertEquals(..Verdict("THAW", "{""WriteState"":""Thawed""}"), "BACKUP.NOTFROZEN", "a thaw while not frozen")
    Do $$$AssertEquals(..Verdict("THAW", "{""WriteState"":""Frozen""}"), "", "a thaw while frozen holds")
    Do $$$AssertEquals(..Verdict("THAW", "{}"), "BACKUP.NOTFROZEN", "and a state that names no write state is not frozen")
}

/// <p>AC1. A run is refused while any task runs, then while writes are frozen; a list change is refused when the list already reflects
/// it.</p>
Method TestARunAndAListChangeAreJudgedAgainstTheirTarget()
{
    Do $$$AssertEquals(..Verdict("RUN", "{""Status"":""Running"",""AnyRunning"":true}"), "BACKUP.RUNNING", "a run while a task runs")
    Do $$$AssertEquals(..Verdict("RUN", "{""Status"":"""",""AnyRunning"":false}"), "", "a run while none runs")
    Do $$$AssertEquals(..Verdict("RUN", "{""Status"":"""",""AnyRunning"":false,""WritesFrozen"":true}"), "BACKUP.FROZEN", "a run while writes are frozen")
    Do $$$AssertEquals(..Verdict("RUN", "{""Status"":""Running"",""AnyRunning"":true,""WritesFrozen"":true}"), "BACKUP.RUNNING", "a running task is judged first")
    Do $$$AssertEquals(..Verdict("ADD", "{""Listed"":true}"), "BACKUP.LIST.CONFLICT", "an add of a listed database")
    Do $$$AssertEquals(..Verdict("ADD", "{""Listed"":false}"), "", "an add of an unlisted one")
    Do $$$AssertEquals(..Verdict("REMOVE", "{""Listed"":false}"), "BACKUP.LIST.CONFLICT", "a remove of an unlisted database")
    Do $$$AssertEquals(..Verdict("REMOVE", "{""Listed"":true}"), "", "a remove of a listed one")
    Do $$$AssertEquals(..Verdict("MOUNT", "{}"), "", "a write type the rules do not judge is not refused here")
}

/// <p>AC1, AD-39. Every code answers its ruled sentence, on its status: a task or database the instance does not hold 404, a bad limit
/// 400, every state conflict 409; the two consequence codes are no refusal.</p>
Method TestEveryCodeCarriesItsRuledSentenceOnItsStatus()
{
    For tCase = $ListBuild("BACKUP.TASK.NOTFOUND", "There is no backup task with that name.", 404), $ListBuild("BACKUP.RUNNING", "A backup is already running.", 409), $ListBuild("BACKUP.FREEZE.LIMIT", "Give a suspend limit from 1 to 600 seconds.", 400), $ListBuild("BACKUP.FROZEN", "Database writes are already frozen.", 409), $ListBuild("BACKUP.FREEZE.UNBOUNDED", "Writes cannot be frozen with a limit on this system.", 409), $ListBuild("BACKUP.NOTFROZEN", "Database writes are not frozen.", 409), $ListBuild("BACKUP.DATABASE.NOTFOUND", "There is no database with that name.", 404), $ListBuild("BACKUP.LIST.CONFLICT", "The backup list already reflects that change.", 409), $ListBuild("BACKUP.RUN", "The backup runs in the background; its result appears in Backup history.", 0), $ListBuild("BACKUP.FREEZE", "Database writes stop until you thaw them or the limit passes.", 0) {
        Set tCode = $List(tCase, 1)
        Do $$$AssertEquals($ClassMethod(..#ERROR, "ReasonFor", tCode), $List(tCase, 2), tCode _ " carries its sentence")
        Do $$$AssertEquals($ClassMethod(..#ERROR, "HttpStatusFor", tCode), $List(tCase, 3), tCode _ " is answered with its status")
        Do $$$AssertEquals(##class(OcuPilot.Api.Error).ReasonForToolCode(tCode), $List(tCase, 2), tCode _ " reaches the error dispatch")
    }
    Do $$$AssertEquals($ClassMethod(..#ERROR, "ReasonFor", "BACKUP.NOPE"), "", "a code the class does not declare carries none")
}

/// <p>AD-55. The write tools' mint asks the same rules: a mint against a state the rules refuse answers the code's sentence, and a tool
/// whose target is the write state refuses any other id.</p>
Method TestTheMintAsksTheSameRulesAndAFixedIdTargetRefusesAnyOther()
{
    Set tSC = $ClassMethod("OcuPilot.Screen.Tool.BackupFreeze", "ArgumentProblem", "OTHER", {"limit": 5}, .tProblem)
    Do $$$AssertStatusOK(tSC, "the freeze's id is judged")
    Do $$$AssertTrue(tProblem [ "SYSTEM", "an id other than SYSTEM is refused naming it: " _ tProblem)
    Set tSC = $ClassMethod("OcuPilot.Screen.Tool.BackupFreeze", "ArgumentProblem", "SYSTEM", {"limit": 0}, .tProblem)
    Do $$$AssertEquals(tProblem, "Give a suspend limit from 1 to 600 seconds.", "a limit of 0 is refused with the ruled sentence at the mint")
    Set tSC = $ClassMethod("OcuPilot.Screen.Tool.BackupThaw", "ArgumentProblem", "SYSTEM", {}, .tProblem)
    Do $$$AssertEquals(tProblem, "Database writes are not frozen.", "a thaw of thawed writes is refused with the ruled sentence at the mint")
    Set tSC = $ClassMethod("OcuPilot.Screen.Tool.BackupRun", "ArgumentProblem", "NoSuchTask", {}, .tProblem)
    Do $$$AssertEquals(tProblem, "There is no backup task with that name.", "a task the list does not hold is refused at the mint")
    Set tSC = $ClassMethod("OcuPilot.Screen.Tool.BackupDatabaseAdd", "ArgumentProblem", "NOSUCHDATABASE", {}, .tProblem)
    Do $$$AssertEquals(tProblem, "There is no database with that name.", "a database the instance does not hold is refused at the mint")
    Set tSC = $ClassMethod("OcuPilot.Screen.Tool.BackupDatabaseRemove", "ArgumentProblem", "IRISTEMP", {}, .tProblem)
    Do $$$AssertEquals(tProblem, "There is no database with that name.", "and the temporary database is never a database of the list")
}

}

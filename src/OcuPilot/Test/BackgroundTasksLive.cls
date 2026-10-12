/// <p>Pins Story 16.5 against real background work (AD-8, AD-16, AD-27, AD-29, AD-53): a seeded
/// Management Portal compact listed as the portal reports it, and read in <code>%SYS</code> by the
/// task error log too; the screen's resume, pause and cancel each acting on it; an admin API compact
/// queued as the test account listed as that account's own and paused through
/// <code>AsyncResult</code>; the agent's confirmed pause of a compact, as the request the vendor
/// records; the seed's teardown ending such a compact after its job stops answering for a while; a
/// holder of the Tasks area's pairs alone refused Background tasks by name; and the task error log
/// refusing a caller without
/// <code>%DB_IRISSYS:READ</code> before its read can rewrite a live job's status.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed in <code>HSCUSTOM</code> and
/// serving over HTTP as <class>OcuPilot.Test.Http</class>'s test account, the admin API answering
/// that account, <code>%System_CallOut:USE</code> to stop and continue a job through
/// <code>$ZF(-100)</code>, and <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because the class
/// creates and deletes three users and three roles, a scratch database
/// (<class>OcuPilot.Test.BackgroundSeed</class>) and one idle job of its own. Each test seeds its own
/// work and removes it.</p>
Class OcuPilot.Test.BackgroundTasksLive Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter SCREEN = "OcuPilot.Screen.Descriptor.BackgroundTaskList";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

Parameter SEED = "OcuPilot.Test.BackgroundSeed";

/// <p>How long <method>TestTheAgentsConfirmPausesACompact</method> waits between resuming its compact
/// and minting the pause: longer than a resumed seed compact takes to finish its work (about two
/// seconds), so an unheld compact would record its end before the confirm.</p>
Parameter RESUMEDSECONDS As INTEGER = 3;

/// <p>How long <method>TestTheTeardownOutlastsAStalledCompact</method> stops its compact's job: past
/// the vendor's cancel of a stopped job (which blocks about 18 s) plus the ten-second wait for its end
/// that the teardown allowed before, and well inside that cancel plus <parameter>OcuPilot.Test.BackgroundSeed.ENDSECONDS</parameter>.</p>
Parameter STALLSECONDS As INTEGER = 35;

/// <p>The purpose-built principal holding the install namespace's code read and the Tasks area's
/// two pairs, and not <code>%Admin_Operate</code>.</p>
Parameter TASKUSER = "OcuPilotBackgroundGateTask";

Parameter TASKROLE = "OcuPilotBackgroundGateTaskRole";

/// <p>The purpose-built principal holding the code read, <code>%Admin_Operate:USE</code> and
/// <code>%Admin_Secure:USE</code>, and not <code>%DB_IRISSYS:READ</code>.</p>
Parameter LOGUSER = "OcuPilotBackgroundGateLog";

Parameter LOGROLE = "OcuPilotBackgroundGateLogRole";

/// <p>The purpose-built principal holding the code read, the Tasks area's two pairs and
/// <code>%Admin_Operate:USE</code> -- everything Background tasks needs -- and not
/// <code>%Admin_Secure:USE</code>.</p>
Parameter READERUSER = "OcuPilotBackgroundReader";

Parameter READERROLE = "OcuPilotBackgroundReaderRole";

/// <p>The throwaway principals' password, generated for the run.</p>
Property PreparedPassword As %String;

/// <p>The admin API tasks this test queued, whose rows its teardown removes.</p>
Property PreparedGuids As %List;

/// <p>The idle job this test started, which its teardown ends.</p>
Property PreparedIdle As %String;

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPassword = ""
    Set ..PreparedGuids = ""
    Set ..PreparedIdle = ""
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.BackgroundTasksLive creates and deletes users, roles and a database on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set ..PreparedPassword = "OcuPilotBgnd" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Quit ..EnsurePrincipals()
}

/// <p>Remove the three principals and their roles; a failing status when any survives.</p>
Method OnAfterAllTests() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        For tUser = ..#TASKUSER, ..#LOGUSER, ..#READERUSER {
            If ##class(Security.Users).Exists(tUser) Do ##class(Security.Users).Delete(tUser)
        }
        For tRole = ..#TASKROLE, ..#LOGROLE, ..#READERROLE {
            If ##class(Security.Roles).Exists(tRole) Do ##class(Security.Roles).Delete(tRole)
        }
        If ##class(Security.Users).Exists(..#TASKUSER) || ##class(Security.Users).Exists(..#LOGUSER) || ##class(Security.Users).Exists(..#READERUSER) || ##class(Security.Roles).Exists(..#TASKROLE) || ##class(Security.Roles).Exists(..#LOGROLE) || ##class(Security.Roles).Exists(..#READERROLE) {
            Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.BackgroundTasksLive left a throwaway principal on the instance")
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

Method OnBeforeOneTest() As %Status
{
    Set ..PreparedGuids = ""
    Set ..PreparedIdle = ""
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Quit $$$OK
}

/// <p>Remove the seeded work: the scratch database and every task over it, the admin API rows this
/// test queued, and its idle job and that job's log entry.</p>
Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do $$$AssertStatusOK($ClassMethod(..#SEED, "Remove"), "the seeded database and its tasks are removed")
    For tI = 1:1:$ListLength(..PreparedGuids) {
        Set tGuid = $List(..PreparedGuids, tI)
        Do $$$AssertStatusOK(##class(OcuPilot.Test.PortFixture).RemoveTaskRow(tGuid), "the queued admin API task's row is removed")
        Do $$$AssertEquals(##class(OcuPilot.Test.PortFixture).TaskRowExists(tGuid), 0, "and is gone")
    }
    If ..PreparedIdle '= "" {
        Kill ^IRIS.Temp.MgtPortalTask(..PreparedIdle)
        Do $SYSTEM.Process.Terminate(..PreparedIdle)
    }
    Set ..PreparedGuids = ""
    Set ..PreparedIdle = ""
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining)
    Do $$$AssertStatusOK(tSC, "the probe proposals and turns are removed")
    Quit $$$OK
}

/// <p>AC1, AD-16: a seeded portal compact is listed by the screen's read as the portal reports it --
/// its source, task, namespace, details, background task state, error count and start time, each
/// equal to the portal's own query row read here in <code>%SYS</code>; and the task error log's
/// reader, which reads in <code>%SYS</code>, sees that state too. The job's error count is set on its
/// job log entry, so that column carries a value to compare.</p>
/// <p>Mutation (Rule 19): drop the portal half from
/// <method>OcuPilot.Port.BackgroundTaskPort.Rows</method> -- the listing leg goes red; read the
/// <code>StartTime</code> column under another name in
/// <method>OcuPilot.Port.BackgroundTaskPort.PortalRows</method> -- the start time leg goes red; read
/// <method>OcuPilot.Port.LogSourcePort.FetchTasks</method> outside <code>%SYS</code> -- the task error
/// log leg goes red.</p>
Method TestASeededPortalCompactIsListedPaused()
{
    Set tSC = $ClassMethod(..#SEED, "PausedCompact", .tJob, .tTaskId)
    Do $$$AssertStatusOK(tSC, "a portal compact is seeded and paused: " _ $System.Status.GetErrorText(tSC))
    If $$$ISERR(tSC) Quit
    Set ^IRIS.Temp.MgtPortalTask(tJob, "ErrorLog") = 2
    Set tRow = ..Listed("Management Portal", tJob)
    Do $$$AssertTrue($IsObject(tRow), "the screen's read lists it")
    If '$IsObject(tRow) Quit
    Do $$$AssertEquals(tRow.%Get("Task") _ " | " _ tRow.%Get("Namespace") _ " | " _ tRow.%Get("Status") _ " | " _ tRow.%Get("Details"), "Compact DB Space | %SYS | Paused | " _ $Parameter(..#SEED, "DATABASE") _ " " _ $ClassMethod(..#SEED, "Directory"), "as the portal's compact in %SYS, paused, with its database as the details")
    Do $$$AssertEquals($ZConvert(tRow.%Get("Database"), "L"), $ZConvert($ClassMethod(..#SEED, "Directory"), "L"), "naming the database its task runs against, compared without case (Story 18.3, DW-1080)")
    Set tVendor = ..VendorRow(tJob)
    Do $$$AssertTrue($IsObject(tVendor) && (tVendor.%Get("StartTime") '= "") && (tVendor.%Get("ErrorCount") = 2), "the portal's own query lists the job with a start time and its error count: " _ $Select($IsObject(tVendor): tVendor.%ToJSON(), 1: ""))
    If '$IsObject(tVendor) Quit
    For tField = "Task", "Namespace", "Status", "Details", "ErrorCount", "StartTime" {
        Do $$$AssertEquals(tRow.%Get(tField), tVendor.%Get(tField), "the listed " _ tField _ " is the portal's own")
    }
    Set tSC = ##class(OcuPilot.Port.LogSourcePort).FetchTasks(.tTasks)
    Do $$$AssertStatusOK(tSC, "the task error log's reader reads the job list")
    Set tStatus = ""
    Set tAt = ""
    For {
        Set tAt = $Order(tTasks(tAt), 1, tTask)
        If tAt = "" Quit
        If $ListGet(tTask, 1) = tJob Set tStatus = $ListGet(tTask, 5)
    }
    Do $$$AssertEquals(tStatus, "Paused", "and reads the job's background task state, as the portal does in %SYS")
}

/// <p>AC2, AD-8, AD-53: the screen's Resume acts on a seeded compact -- 200, the updated change
/// event's triple, and the compact running again -- and its Pause, sent by
/// <parameter>READERUSER</parameter>, who holds the screen's pairs and nothing more, answers 200 or
/// the vendor's state refusal of a compact that already ended. A 200 is followed by the screen's
/// Cancel (200, the row re-reads Cancelled) and a Pause of the canceled compact (409
/// <code>TASK.BACKGROUND.STATE</code> with the published sentence); a refusal is followed by a Cancel
/// of the ended compact that answers 409 <code>TASK.BACKGROUND.STATE</code>. Any other answer to the
/// Pause fails.</p>
/// <p>The live leg accepts the ended compact's state refusal, and
/// <class>OcuPilot.Test.BackgroundTaskPortSeam</class> pins the 200 path at the port.</p>
/// <p>Mutation (Rule 19): skip the vendor call in
/// <method>OcuPilot.Port.BackgroundTaskPort.PortalControl</method> -- the compact does not run again
/// and the resume leg goes red; add <code>%Admin_Secure:USE</code> to
/// <parameter>OcuPilot.Port.BackgroundTaskPort.PAIRS</parameter> -- the least-privileged Pause is
/// refused 403 and goes red.</p>
Method TestTheScreensActionsResumePauseAndCancelACompact()
{
    Set tSC = $ClassMethod(..#SEED, "PausedCompact", .tJob, .tTaskId)
    Do $$$AssertStatusOK(tSC, "a portal compact is seeded and paused: " _ $System.Status.GetErrorText(tSC))
    If $$$ISERR(tSC) Quit
    Set tId = ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild("Management Portal", tJob))
    Set tSC = ..Act("resume", tId, "", "", .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "the screen's Resume answers 200: " _ $Select($IsObject(tBody): tBody.%ToJSON(), 1: tBody))
    Do $$$AssertTrue($IsObject(tBody) && $IsObject(tBody.%Get("target")), "and answers the change event: " _ $Select($IsObject(tBody): tBody.%ToJSON(), 1: tBody))
    If $IsObject(tBody) && $IsObject(tBody.%Get("target")) Do $$$AssertEquals(tBody.%Get("action") _ " " _ tBody.%Get("target").%Get("type") _ " " _ tBody.%Get("target").%Get("scope") _ " " _ (tBody.%Get("target").%Get("id") = tId), "updated background-task instance 1", "publishing the updated event for the row")
    Do $$$AssertTrue($ListFind($ListBuild("Running", "Done"), $ClassMethod(..#SEED, "State", tTaskId)), "and the compact runs again: " _ $ClassMethod(..#SEED, "State", tTaskId))
    Set tSC = ..Act("pause", tId, ..#READERUSER, ..PreparedPassword, .tStatus, .tBody)
    Set tPauseBody = $Select($IsObject(tBody): tBody.%ToJSON(), 1: tBody)
    If tStatus '= 200 {
        Set tEnded = $ClassMethod(..#SEED, "State", tTaskId)
        Set tRefused = (tStatus _ " " _ ..Code(tBody) _ " " _ tEnded = "409 TASK.BACKGROUND.STATE Done")
        Do $$$AssertTrue(tRefused, "a Pause that is not a 200 is only the state refusal of a compact that already ended: " _ tStatus _ " " _ tEnded _ " " _ tPauseBody)
        If 'tRefused Quit
        Set tSC = ..Act("cancel", tId, "", "", .tStatus, .tBody)
        Do $$$AssertEquals(tStatus _ " " _ ..Code(tBody), "409 TASK.BACKGROUND.STATE", "and so is the screen's Cancel of it: " _ $Select($IsObject(tBody): tBody.%ToJSON(), 1: tBody))
        Quit
    }
    Do $$$AssertEquals(..StatusOf("Management Portal", tJob), "Paused", "the screen's Pause answers 200 to a holder of the screen's pairs alone, and the row re-reads Paused")
    Set tSC = ..Act("cancel", tId, "", "", .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "the screen's Cancel answers 200: " _ $Select($IsObject(tBody): tBody.%ToJSON(), 1: tBody))
    Set tState = ""
    For tI = 1:1:100 {
        Set tState = ..StatusOf("Management Portal", tJob)
        If tState = "Cancelled" Quit
        Hang 0.05
    }
    Do $$$AssertEquals(tState, "Cancelled", "and the row re-reads Cancelled")
    Set tSC = ..Act("pause", tId, "", "", .tStatus, .tBody)
    Do $$$AssertEquals(tStatus _ " " _ ..Code(tBody) _ " " _ $Select($IsObject(tBody): tBody.%Get("reason"), 1: ""), "409 TASK.BACKGROUND.STATE " _ ##class(OcuPilot.Api.Error).#REASONTASKBACKGROUNDSTATE, "a Pause of the canceled compact is the vendor's state refusal, with the published sentence: " _ $Select($IsObject(tBody): tBody.%ToJSON(), 1: tBody))
}

/// <p>AC1, AC3: an admin API compact queued over HTTP as the test account is listed as that
/// account's own, under "Admin API" with its GUID as the id; the screen's Pause reaches it through
/// <code>AsyncResult</code>, and <code>AsyncResult</code>'s own refusal of a cancel while it is paused
/// is the published <code>TASK.BACKGROUND.STATE</code>; Resume sets it running again.</p>
/// <p>While it is paused it is listed once, on its admin API row, naming the database it runs against
/// (DW-1821).</p>
/// <p>Mutation (Rule 19): drop the admin half from
/// <method>OcuPilot.Port.BackgroundTaskPort.Rows</method> -- the listing leg goes red.</p>
Method TestAnAdminApiCompactIsListedAndPausedThroughAsyncResult()
{
    Set tSC = $ClassMethod(..#SEED, "Prepare")
    Do $$$AssertStatusOK(tSC, "the scratch database is filled: " _ $System.Status.GetErrorText(tSC))
    If $$$ISERR(tSC) Quit
    Set tBody = {}
    Do tBody.%Set("TargetFreeSpace", $Parameter(..#SEED, "TARGETMB"), "number")
    Set tPath = "/api/admin/v2/database-dir/compact?dir=" _ $ZConvert($ClassMethod(..#SEED, "Directory"), "O", "URL")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", tPath, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tStatus, .tRaw, .tHeaders, tBody.%ToJSON(), "application/json")
    Set tGuid = $Piece($Piece($Get(tHeaders("LOCATION")), "id=", 2), "&", 1)
    If tGuid '= "" Set ..PreparedGuids = ..PreparedGuids _ $ListBuild(tGuid)
    Do $$$AssertEquals(tStatus, 202, "the admin API queues the compact: " _ tRaw)
    Do $$$AssertTrue(tGuid '= "", "and names its task's GUID: " _ $Get(tHeaders("LOCATION")))
    If tGuid = "" Quit
    Set tState = ""
    For tI = 1:1:100 {
        Set tState = ..StatusOf("Admin API", tGuid)
        If tState '= "Queued" Quit
        Hang 0.02
    }
    Set tRow = ..Listed("Admin API", tGuid)
    Do $$$AssertTrue($IsObject(tRow), "the screen's read lists it as the test account's own admin API task")
    If '$IsObject(tRow) Quit
    Do $$$AssertEquals(tRow.%Get("Task") _ " | " _ tRow.%Get("Namespace") _ " | " _ tRow.%Get("ErrorCount") _ " | " _ tRow.%Get("Status"), "POST /v2/database-dir/compact |  |  | Running", "by its route, with no namespace or error count, running: " _ tRow.%ToJSON())
    Do $$$AssertTrue(tRow.%Get("StartTime") ? 4N1"-"2N1"-"2N1" "2N1":"2N1":"2N.E, "and the time it started: " _ tRow.%ToJSON())
    Set tId = ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild("Admin API", tGuid))
    Set tSC = ..Act("pause", tId, "", "", .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus, 200, "the screen's Pause answers 200: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: tAnswer))
    Do $$$AssertEquals(..StatusOf("Admin API", tGuid), "Paused", "and the row re-reads Paused")
    ; DW-1821 (Story 18.4): the paused compact is listed once, on its admin API row, with its database.
    Set tDirectory = $ZConvert(##class(%File).NormalizeDirectory($ClassMethod(..#SEED, "Directory")), "U")
    Set tPaused = ..Listed("Admin API", tGuid)
    Do $$$AssertEquals($Select($IsObject(tPaused): $ZConvert(##class(%File).NormalizeDirectory(tPaused.%Get("Database")), "U"), 1: ""), tDirectory, "the admin row names the database its task runs against")
    Do $$$AssertEquals(..ListedFor(tDirectory), 1, "and the task is listed once")
    Set tSC = ..Act("cancel", tId, "", "", .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus _ " " _ ..Code(tAnswer) _ " " _ $Select($IsObject(tAnswer): tAnswer.%Get("reason"), 1: ""), "409 TASK.BACKGROUND.STATE " _ ##class(OcuPilot.Api.Error).#REASONTASKBACKGROUNDSTATE, "AsyncResult refuses to cancel a paused compact, with the published sentence")
    Set tSC = ..Act("resume", tId, "", "", .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus, 200, "the screen's Resume answers 200: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: tAnswer))
    Do $$$AssertTrue($ListFind($ListBuild("Running", "Finished"), ..StatusOf("Admin API", tGuid)), "and the row re-reads running or finished")
}

/// <p>AC1: the admin API half is the caller's own. An async task row the test account owns is
/// listed for that account, its GUID's leading zero kept, and not for another principal who holds
/// every pair the screen needs.</p>
/// <p>Mutation (Rule 19): give <class>OcuPilot.Port.AdminPort</class>'s stub <code>%session</code> the
/// test account's name in place of <code>$USERNAME</code> -- the other principal lists the row and
/// this goes red.</p>
Method TestAnotherCallersAdminTaskIsNotListed()
{
    Set tOwner = ##class(OcuPilot.Test.Http).GetTestUsername()
    Set tGuid = "0165" _ $Translate($ZTimeStamp, ",.", "")
    Set tSC = ##class(OcuPilot.Test.PortFixture).SeedTaskRow(tGuid, "POST /v2/database-dir/compact", "Finished", $ZDateTime($Horolog, 3), tOwner)
    Do $$$AssertStatusOK(tSC, "an async task row owned by " _ tOwner _ " is seeded")
    If $$$ISERR(tSC) Quit
    Set ..PreparedGuids = ..PreparedGuids _ $ListBuild(tGuid)
    Do $$$AssertTrue($IsObject(..Listed("Admin API", tGuid)), "its owner's read lists it under its GUID, the leading zero kept")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", $Parameter("OcuPilot.Test.Http", "BASEPATH") _ "/screens/tasks.background/read?maxRows=1000", ..#READERUSER, ..PreparedPassword, .tStatus, .tRaw, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "another principal holding the screen's pairs reads the list: " _ $Get(tRaw))
    Set tListed = 0
    Try {
        Set tIterator = ##class(%DynamicObject).%FromJSON(tRaw).%Get("rows").%GetIterator()
        While tIterator.%GetNext(.tIndex, .tEntry) {
            If (tEntry.%Get("Source") = "Admin API") && (tEntry.%Get("Id") = tGuid) Set tListed = 1
        }
    } Catch {
        Set tListed = -1
    }
    Do $$$AssertEquals(tListed, 0, "and does not see " _ tOwner _ "'s admin API task")
}

/// <p>AC2, AD-15: the agent's proposal to pause a running compact shows its status moving to
/// Paused, and its confirm applies, the vendor records the pause request, and the agent marker
/// lands.</p>
/// <p>The compact is held (<method>OcuPilot.Test.BackgroundSeed.Hold</method>) before it is resumed,
/// and the mint waits <parameter>RESUMEDSECONDS</parameter> after the resume, so the compact's work
/// is done before the mint while its end is not recorded. A held compact whose work is done reads
/// Running after the pause, so the leg reads the pause request, not the state.</p>
/// <p>A held compact that still ends before the confirm is answered by the target-changed refusal,
/// which the test asserts, and a fresh compact is seeded, at most three in all.</p>
/// <p>Mutation (Rule 19): drop the <method>OcuPilot.Test.BackgroundSeed.Hold</method> call -- the
/// compact records Done before the mint and this goes red; fingerprint the tools over a value that
/// moves on every read -- every confirm is refused and this goes red.</p>
Method TestTheAgentsConfirmPausesACompact()
{
    ; A held compact can still end before the confirm on a slow host, and the confirm is then the
    ; target-changed refusal, asserted as such; a fresh compact and turn are seeded, at most three.
    Set tConfirmed = 0
    For tTry = 1:1:3 {
        Set tSC = $ClassMethod(..#SEED, "PausedCompact", .tJob, .tTaskId)
        Do $$$AssertStatusOK(tSC, "a portal compact is seeded and paused: " _ $System.Status.GetErrorText(tSC))
        If $$$ISERR(tSC) Quit
        Set tSC = $ClassMethod(..#SEED, "Hold", tTaskId)
        Do $$$AssertStatusOK(tSC, "its end is held: " _ $System.Status.GetErrorText(tSC))
        If $$$ISERR(tSC) Quit
        Set tId = ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild("Management Portal", tJob))
        Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurn)
        Do $$$AssertStatusOK(tSC, "a turn is seeded")
        If $$$ISERR(tSC) Quit
        Kill tQuery
        Set tQuery("id") = tId
        Set tSC = ##class(OcuPilot.Port.BackgroundTaskPort).Invoke("BackgroundTask", "RESUME", .tQuery, "", .tResult, .tHttp, .tFault)
        Do $$$AssertStatusOK(tSC, "the compact is resumed through the port")
        Hang ..#RESUMEDSECONDS
        Set tTool = "OcuPilot.Screen.Tool.BackgroundTaskPause"
        Set tArgs = {"source": "Management Portal"}
        Do tArgs.%Set("id", tJob, "string")
        Set tSC = ##class(OcuPilot.Screen.Tool.BackgroundTaskMint).Mint(..#SCREEN, "tasks.background.pause", $Username, "", tTurn, tArgs, ..#LIMITS, .tProposal, .tHttp, .tFault, $ClassMethod(tTool, "Endpoint"), $ClassMethod(tTool, "IdParam"), tJob, $ClassMethod(tTool, "IdArgument"), $ClassMethod(tTool, "SettableFields"), tTool)
        Do $$$AssertStatusOK(tSC, "the pause mints: " _ $System.Status.GetErrorText(tSC) _ " (the compact read " _ $ClassMethod(..#SEED, "State", tTaskId) _ ")")
        If $$$ISERR(tSC) Quit
        Do $$$AssertEquals(tProposal.%Get("changed").%ToJSON(), "[{""field"":""Status"",""before"":""Running"",""after"":""Paused""}]", "the card shows the status moving to Paused")
        Kill tCode
        Set tSC = ##class(OcuPilot.Kernel.Proposal.Confirm).Confirm(tProposal.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
        If $$$ISOK(tSC) Set tConfirmed = 1 Quit
        Set tEnded = $ClassMethod(..#SEED, "State", tTaskId)
        Do $$$AssertTrue(($Get(tCode) = "PROPOSAL.TARGETCHANGED") && $ListFind($ListBuild("Exited", "Done"), tEnded), "a refused confirm is only the target-changed refusal of a compact that already ended (seed " _ tTry _ "): " _ $Get(tCode) _ " " _ tEnded)
        Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
        If '(($Get(tCode) = "PROPOSAL.TARGETCHANGED") && $ListFind($ListBuild("Exited", "Done"), tEnded)) Quit
    }
    Do $$$AssertTrue(tConfirmed, "the confirm applies on one of three seeded compacts: " _ $Get(tCode) _ " (the compact then read " _ $ClassMethod(..#SEED, "State", tTaskId) _ ")")
    If 'tConfirmed Quit
    Do $$$AssertEquals($ClassMethod(..#SEED, "RequestOf", tTaskId), 1, "and the vendor records the pause request")
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditMarker).WriteRow(tTurn, .tLedger), 1, "one write-kind ledger row")
    Do $$$AssertEquals($Get(tLedger("AuditMarked")), $Parameter("OcuPilot.Kernel.State.Ledger", "MARKEDYES"), "and the agent marker landed on it")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
}

/// <p>The seed's teardown ends the agent leg's compact after its job stops answering for a while, as
/// a CI host whose writes stall stops it (inference): the compact is held, resumed and paused through
/// the port in that leg's order, its job is stopped for <parameter>STALLSECONDS</parameter>, and
/// <method>OcuPilot.Test.BackgroundSeed.Remove</method> still removes the database and every task over
/// it, so the next test's seed is not refused.</p>
/// <p>Mutation (Rule 19): wait ten seconds for the canceled task's end in
/// <method>OcuPilot.Test.BackgroundSeed.Remove</method>, or count a task that does not open as ended
/// -- the removal answers #9501 and leaves the task over the seed, and this goes red.</p>
Method TestTheTeardownOutlastsAStalledCompact()
{
    Set tSC = $ClassMethod(..#SEED, "PausedCompact", .tJob, .tTaskId)
    Do $$$AssertStatusOK(tSC, "a portal compact is seeded and paused: " _ $System.Status.GetErrorText(tSC))
    If $$$ISERR(tSC) Quit
    Set tSC = $ClassMethod(..#SEED, "Hold", tTaskId)
    Do $$$AssertStatusOK(tSC, "its end is held: " _ $System.Status.GetErrorText(tSC))
    If $$$ISERR(tSC) Quit
    Kill tQuery
    Set tQuery("id") = ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild("Management Portal", tJob))
    Set tSC = ##class(OcuPilot.Port.BackgroundTaskPort).Invoke("BackgroundTask", "RESUME", .tQuery, "", .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the compact is resumed through the port")
    Hang ..#RESUMEDSECONDS
    Set tSC = ##class(OcuPilot.Port.BackgroundTaskPort).Invoke("BackgroundTask", "PAUSE", .tQuery, "", .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "and paused through the port, as the confirm pauses it")
    Do $$$AssertEquals($ClassMethod(..#SEED, "RequestOf", tTaskId), 1, "the vendor records the pause request")
    Set tSC = $ClassMethod(..#SEED, "Stall", tJob, ..#STALLSECONDS)
    Do $$$AssertStatusOK(tSC, "its job is stopped for " _ ..#STALLSECONDS _ " s: " _ $System.Status.GetErrorText(tSC))
    If $$$ISERR(tSC) Quit
    Set tSC = $ClassMethod(..#SEED, "Remove")
    Do $$$AssertStatusOK(tSC, "the seed's removal outlasts the stall: " _ $System.Status.GetErrorText(tSC))
    Do $$$AssertEquals($ListLength($ClassMethod(..#SEED, "Tasks", 0)), 0, "and leaves no task over the seed database, so the next seed is not refused")
}

/// <p>AD-8's own-pair case: a holder of the Tasks area's two pairs alone keeps the area and its
/// other screens, while Background tasks is shown and refused on <code>%Admin_Operate:USE</code>, and
/// its read is refused naming that pair.</p>
/// <p>Mutation (Rule 19): drop <code>%Admin_Operate:USE</code> from the descriptor's
/// <code>privileges</code> and <code>ownPrivileges</code> -- Background tasks reads open and this goes
/// red.</p>
Method TestATasksHolderKeepsTheAreaAndIsRefusedBackgroundTasks()
{
    Set tBase = $Parameter("OcuPilot.Test.Http", "BASEPATH")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ "/navigation", ..#TASKUSER, ..PreparedPassword, .tStatus, .tRaw, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "the navigation map answers the principal")
    Set tArea = ""
    Try {
        Set tIterator = ##class(%DynamicObject).%FromJSON(tRaw).%Get("areas").%GetIterator()
        While tIterator.%GetNext(.tIndex, .tEntry) {
            If tEntry.%Get("key") = "tasks" Set tArea = tEntry
        }
    } Catch {}
    Do $$$AssertTrue($IsObject(tArea) && (tArea.%Get("allowed") = 1), "and carries the Tasks area, open")
    If '$IsObject(tArea) Quit
    Set tVerdicts = ""
    Set tIterator = tArea.%Get("screens").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tScreen) {
        If tScreen.%Get("sideBarPosition") = 0 Continue
        Set tVerdicts = tVerdicts _ $ListBuild(tScreen.%Get("route") _ "=" _ $Select(tScreen.%Get("allowed"): "open", 1: tScreen.%Get("failedPair")))
    }
    Do $$$AssertEquals($ListToString(tVerdicts, " "), "tasks/schedule=open tasks/on-demand=open tasks/upcoming=open tasks/history=open tasks/background=%Admin_Operate:USE", "its other screens are open, and Background tasks is refused on its own pair")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ "/screens/tasks.background/read?maxRows=5", ..#TASKUSER, ..PreparedPassword, .tStatus, .tRaw, .tHeaders)
    Set tBody = ""
    Try { Set tBody = ##class(%DynamicObject).%FromJSON(tRaw) } Catch {}
    Do $$$AssertEquals(tStatus _ " " _ ..Code(tBody) _ " " _ ..FailedPair(tBody), "403 AUTH.NOPRIVILEGE %Admin_Operate:USE", "and its read is refused naming that pair")
}

/// <p>AD-29: a caller holding <code>%Admin_Operate:USE</code> without <code>%DB_IRISSYS:READ</code> is
/// refused the task error log by name, and a live job's stored status stays Running, where the
/// portal's query would have rewritten it to Exited for a caller that cannot see the process.</p>
/// <p>Mutation (Rule 19): drop <code>%DB_IRISSYS:READ</code> from
/// <parameter>OcuPilot.Port.LogSourcePort.TASKERRORSPAIRS</parameter> -- the refusal leg goes
/// red.</p>
Method TestTheTaskErrorLogRequiresTheSystemRead()
{
    Job ##class(OcuPilot.Test.BackgroundTasksLive).Idle(30)::10
    Set tPid = $ZChild
    Do $$$AssertTrue(tPid > 0, "an idle job of this test's own starts")
    If tPid = 0 Quit
    Set ..PreparedIdle = tPid
    Set ^IRIS.Temp.MgtPortalTask(tPid, "Task") = "OcuPilot idle probe"
    Set ^IRIS.Temp.MgtPortalTask(tPid, "StartTime") = $ZDateTime($Horolog, 3)
    Set ^IRIS.Temp.MgtPortalTask(tPid, "NS") = $NAMESPACE
    Set ^IRIS.Temp.MgtPortalTask(tPid, "Status") = "Running"
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", "/api/ocupilot/logs/taskerrors", ..#LOGUSER, ..PreparedPassword, .tStatus, .tRaw, .tHeaders)
    Set tBody = ""
    Try { Set tBody = ##class(%DynamicObject).%FromJSON(tRaw) } Catch {}
    Do $$$AssertEquals(tStatus _ " " _ ..FailedPair(tBody), "403 %DB_IRISSYS:READ", "the task error log is refused naming the system read: " _ tRaw)
    Do $$$AssertEquals($Get(^IRIS.Temp.MgtPortalTask(tPid, "Status")), "Running", "and the live job's stored status stays Running")
}

/// <p>The body of this test's idle job: wait <var>pSeconds</var>, then end.</p>
ClassMethod Idle(pSeconds As %Integer)
{
    Hang pSeconds
}

/// <p>The row the screen's read lists as the test account for <var>pSource</var> and
/// <var>pId</var>, or <code>""</code>.</p>
Method Listed(pSource As %String, pId As %String) As %DynamicObject
{
    Set tFound = ""
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", $Parameter("OcuPilot.Test.Http", "BASEPATH") _ "/screens/tasks.background/read?maxRows=1000", ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tStatus, .tRaw, .tHeaders)
    If $$$ISERR(tSC) || (tStatus '= 200) Quit ""
    Set tRead = ""
    Try { Set tRead = ##class(%DynamicObject).%FromJSON(tRaw) } Catch {}
    If '$IsObject(tRead) || '$IsObject(tRead.%Get("rows")) Quit ""
    Set tIterator = tRead.%Get("rows").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tEntry) {
        If (tEntry.%Get("Source") = pSource) && (tEntry.%Get("Id") = pId) Set tFound = tEntry
    }
    Quit tFound
}

/// <p>How many rows the screen's read lists as the test account whose <code>Database</code> is the
/// directory <var>pDirectory</var>, normalized and upper-cased; <code>-1</code> when the read fails.</p>
Method ListedFor(pDirectory As %String) As %Integer
{
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", $Parameter("OcuPilot.Test.Http", "BASEPATH") _ "/screens/tasks.background/read?maxRows=1000", ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tStatus, .tRaw, .tHeaders)
    If $$$ISERR(tSC) || (tStatus '= 200) Quit -1
    Set tRead = ""
    Try { Set tRead = ##class(%DynamicObject).%FromJSON(tRaw) } Catch {}
    If '$IsObject(tRead) || '$IsObject(tRead.%Get("rows")) Quit -1
    Set tCount = 0
    Set tIterator = tRead.%Get("rows").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tEntry) {
        If tEntry.%Get("Database") = "" Continue
        If $ZConvert(##class(%File).NormalizeDirectory(tEntry.%Get("Database")), "U") = pDirectory Set tCount = tCount + 1
    }
    Quit tCount
}

/// <p>The status the screen's read lists for <var>pSource</var> and <var>pId</var>, or
/// <code>""</code>.</p>
Method StatusOf(pSource As %String, pId As %String) As %String
{
    Set tRow = ..Listed(pSource, pId)
    Quit $Select($IsObject(tRow): tRow.%Get("Status"), 1: "")
}

/// <p>The row the classic page's own query answers for job <var>pJob</var>, read in
/// <code>%SYS</code> by this test's own account, as <code>{Task, Namespace, Status, Details,
/// ErrorCount, StartTime}</code>, or <code>""</code>.</p>
ClassMethod VendorRow(pJob As %String) As %DynamicObject
{
    Set tFound = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tRS = ##class(%ResultSet).%New("%CSP.UI.System.BackgroundTask:EnumerateTasks")
        If $IsObject(tRS) && $$$ISOK(tRS.Execute()) {
            While tRS.Next() {
                If tRS.GetData(1) '= pJob Continue
                Set tFound = {}
                For tField = "Task", "Namespace", "Status", "Details", "ErrorCount", "StartTime" {
                    Do tFound.%Set(tField, tRS.Get(tField) _ "", "string")
                }
            }
            Do tRS.Close()
        }
        Set tRS = ""
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tFound = ""
    }
    Quit tFound
}

/// <p>One row action <var>pAction</var> over the route as <var>pUser</var>, or as the test account
/// when <var>pUser</var> is empty, answering the HTTP status and the parsed envelope.</p>
Method Act(pAction As %String, pId As %String, pUser As %String, pPassword As %String, Output pStatus As %Integer, Output pBody) As %Status
{
    Set pBody = ""
    If pUser = "" {
        Set pUser = ##class(OcuPilot.Test.Http).GetTestUsername()
        Set pPassword = ##class(OcuPilot.Test.Http).GetTestPassword()
    }
    Set tRequest = {}
    Do tRequest.%Set("action", pAction, "string")
    Do tRequest.%Set("id", pId, "string")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", $Parameter("OcuPilot.Test.Http", "BASEPATH") _ "/screens/tasks.background/action", pUser, pPassword, .pStatus, .tRaw, .tHeaders, tRequest.%ToJSON(), "application/json")
    Try { Set pBody = ##class(%DynamicObject).%FromJSON(tRaw) } Catch { Set pBody = $Get(tRaw) }
    Quit tSC
}

/// <p>The code an envelope <var>pBody</var> carries, or <code>""</code>.</p>
ClassMethod Code(pBody) As %String
{
    If '$IsObject(pBody) Quit ""
    Quit pBody.%Get("code")
}

/// <p>The failed pair an envelope <var>pBody</var>'s detail names, or <code>""</code>.</p>
ClassMethod FailedPair(pBody) As %String
{
    If '$IsObject(pBody) || '$IsObject(pBody.%Get("detail")) Quit ""
    Quit pBody.%Get("detail").%Get("failedPair")
}

/// <p>Create the three throwaway roles and the accounts that hold them, then read the grants back.</p>
Method EnsurePrincipals() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set tInstallNs = ##class(OcuPilot.Install.Installer).ResolveNamespace()
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISERR(tSC) Quit
        Set tNamespace = ##class(Config.Namespaces).Open(tInstallNs)
        Set tDatabase = ##class(Config.Databases).Open(tNamespace.Routines)
        Set tCode = ##class(SYS.Database).%OpenId(tDatabase.Directory).ResourceName _ ":R"
        For tCase = $ListBuild(..#TASKUSER, ..#TASKROLE, tCode _ ",%DB_IRISSYS:R,%Admin_Task:U", "%Admin_Task:USE,%DB_IRISSYS:READ", "%Admin_Operate:USE"), $ListBuild(..#LOGUSER, ..#LOGROLE, tCode _ ",%Admin_Operate:U,%Admin_Secure:U", "%Admin_Operate:USE,%Admin_Secure:USE", "%DB_IRISSYS:READ"), $ListBuild(..#READERUSER, ..#READERROLE, tCode _ ",%DB_IRISSYS:R,%Admin_Task:U,%Admin_Operate:U", "%Admin_Task:USE,%DB_IRISSYS:READ,%Admin_Operate:USE", "%Admin_Secure:USE") {
            Set tUser = $List(tCase, 1)
            Set tRole = $List(tCase, 2)
            If ##class(Security.Users).Exists(tUser) Do ##class(Security.Users).Delete(tUser)
            If ##class(Security.Roles).Exists(tRole) Do ##class(Security.Roles).Delete(tRole)
            Set tSC = ##class(Security.Roles).Create(tRole, "OcuPilot test: the background task gate (throwaway)", $List(tCase, 3), "")
            If $$$ISERR(tSC) Quit
            Set tSC = ##class(Security.Users).Create(tUser, tRole, ..PreparedPassword, "OcuPilot background task test principal (throwaway)", "", "", "", 0, 1, "Created by OcuPilot.Test.BackgroundTasksLive; deleted in OnAfterAllTests")
            If $$$ISERR(tSC) Quit
            Set tHeld = $ListFromString($List(tCase, 4))
            For tI = 1:1:$ListLength(tHeld) {
                If $SYSTEM.Security.CheckUserPermission(tUser, $Piece($List(tHeld, tI), ":", 1), $Piece($List(tHeld, tI), ":", 2)) '= 1 Set tSC = $$$ERROR($$$GeneralError, "the throwaway principal " _ tUser _ " does not hold " _ $List(tHeld, tI))
            }
            Set tLacked = $List(tCase, 5)
            If $SYSTEM.Security.CheckUserPermission(tUser, $Piece(tLacked, ":", 1), $Piece(tLacked, ":", 2)) = 1 Set tSC = $$$ERROR($$$GeneralError, "the throwaway principal " _ tUser _ " holds " _ tLacked)
            If $$$ISERR(tSC) Quit
        }
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

}
